// ======================================================================================
// Mod Name: NCZoningCore
// File: NCZoningFetcher.reds
// Author: Spuddeh
// Description: NCZoningFetcher - the network lifecycle. A ScriptableSystem (so it has
//              GetGameInstance() for the DelaySystem bounce, which a ScriptableService
//              lacks). On Session/Ready it fetches /v1/locations?full=1 once per game
//              launch, parses on the HTTP worker thread, then bounces to the game thread
//              via DelaySystem before swapping NCZoningService's live store. Retries x3.
//
//              RedHttpClient is a SOFT dependency: every reference to it is gated behind
//              @if(ModuleExists("RedHttpClient")), so the mod builds without the plugin.
//              That build has no network layer and serves only a locations_full.json the
//              player supplies by hand; if it is absent, ReportNoData tells them so.
// Mod Version: 0.2.0 (Pre-release)
// Credits: psiberx (Codeware), rayshader (RedHttpClient, RedData, RedFileSystem)
// ======================================================================================

module NCZoning.Core

import NCZoning.Data.*
import RedData.Json.*

// Keep the @if: an ungated import of an absent module is a hard UNRESOLVED_IMPORT error.
@if(ModuleExists("RedHttpClient"))
import RedHttpClient.*

// Compile-time capability probe, surfaced on the public API as IsHttpAvailable().
@if(ModuleExists("RedHttpClient"))
public func NCZHttpAvailable() -> Bool { return true; }

@if(!ModuleExists("RedHttpClient"))
public func NCZHttpAvailable() -> Bool { return false; }

public class NCZoningFetcher extends ScriptableSystem {
  private let m_gi: GameInstance;   // captured on the game thread; used to arm the bounce
  private let m_done: Bool;         // one fetch per game launch (system persists across saves)
  private let m_retries: Int32;
  private let m_readyDispatched: Bool;   // NCZoning-DataReady fired once (cache load or first 200)

  // "No data" message state. The failure and the HUD coming up can happen in either order, so
  // each side sets its flag and calls TryShowNoDataMessage(); it fires once both hold.
  private let m_hudReady: Bool;
  private let m_pendingReason: String;
  private let m_messageShown: Bool;   // once per launch (this system survives save loads)

  private func OnAttach() -> Void {
    GameInstance.GetCallbackSystem()
      .RegisterCallback(n"Session/Ready", this, n"OnSessionReady")
      .SetLifetime(CallbackLifetime.Forever);
  }

  protected cb func OnSessionReady(event: ref<GameSessionEvent>) -> Void {
    let reqs = GameInstance.GetSystemRequestsHandler();
    if IsDefined(reqs) && reqs.IsPreGame() {
      return;
    }
    this.m_gi = this.GetGameInstance();   // capture on the game thread (safe to reuse off-thread)
    if this.m_done {
      return;                              // already fetched this launch
    }
    this.m_done = true;
    this.m_retries = 0;
    // Offline-first: load the file now (store becomes ready + stale), then revalidate if we can.
    let svc = NCZoningService.Get();
    if IsDefined(svc) && svc.LoadCache() {
      let count = svc.GetLocationCount();
      NCZoningLog(s"loaded \(count) locations from cache (stale until revalidated)");
      NCZoningDataEvent.Dispatch(n"NCZoning-DataReady", svc.GetDataVersion(), count, "");   // reds consumers
      NCZoningApi.NotifyDataReady(count, svc.GetDataVersion(), false);                       // CET Lua consumers
      this.m_readyDispatched = true;
    }
    this.DoFetch();
  }

  // --- network layer (RedHttpClient present) -------------------------------------------

  // Runs on the game thread (Session/Ready, or a retry bounce). Public so NCZRetry can call it.
  @if(ModuleExists("RedHttpClient"))
  public func DoFetch() -> Void {
    let url = "https://api.nczoning.net/v1/locations?full=1";
    let headers: array<HttpHeader>;
    let svc = NCZoningService.Get();
    if IsDefined(svc) {
      let etag = svc.GetEtag();
      if StrLen(etag) > 0 {
        ArrayPush(headers, HttpHeader.Create("If-None-Match", etag));   // -> 304 if unchanged
      }
    }
    let callback = HttpCallback.Create(this, n"OnHttpResponse");
    AsyncHttpClient.Get(callback, url, headers);
    NCZoningLog(s"fetch started (conditional=\(ArraySize(headers) > 0))");
  }

  // HTTP callback - runs on a RED4ext JobQueue WORKER thread (Invariant #1). Parse only
  // here (pure data, no game state); hand the result to the game thread via DelaySystem.
  @if(ModuleExists("RedHttpClient"))
  private cb func OnHttpResponse(response: ref<HttpResponse>) -> Void {
    if !IsDefined(response) {
      NCZoningLog("no response");
      this.ScheduleRetry();
      return;
    }
    let status = response.GetStatus();

    // 304: the cached copy is current. Bounce to clear the stale flag (store already loaded).
    if Equals(status, HttpStatus.NotModified) {
      NCZoningLog("304 Not Modified - cache is current");
      let confirm = new NCZApplyResult();
      confirm.m_fetcher = this;
      confirm.m_notModified = true;
      GameInstance.GetDelaySystem(this.m_gi).DelayCallback(confirm, 0.0);
      return;
    }

    if !Equals(status, HttpStatus.OK) {
      NCZoningLog(s"fetch failed (status \(response.GetStatusCode()))");
      this.ScheduleRetry();
      return;
    }

    // 200: parse the new payload on the worker thread (pure data, no game state).
    let body = response.GetText();
    let obj = ParseJson(body) as JsonObject;
    if !IsDefined(obj) {
      NCZoningLog("response body did not parse as a JSON object");
      this.ScheduleRetry();
      return;
    }
    let dataArr = obj.GetKey("data") as JsonArray;
    if !IsDefined(dataArr) {
      NCZoningLog("response has no data array");
      this.ScheduleRetry();
      return;
    }
    let locs: array<ref<NCZLocation>>;
    let total = dataArr.GetSize();
    let k: Uint32 = 0u;
    while k < total {
      let item = dataArr.GetItem(k) as JsonObject;
      if IsDefined(item) {
        ArrayPush(locs, NCZLocation.FromJsonObject(item));
      }
      k += 1u;
    }
    NCZoningLog(s"parsed \(ArraySize(locs)) locations on the worker thread; bouncing to game thread");

    // Bounce to the game thread before swapping the store / writing cache (Invariant #1).
    let apply = new NCZApplyResult();
    apply.m_fetcher = this;
    apply.m_notModified = false;
    apply.m_locations = locs;
    apply.m_datasetVersion = obj.GetKeyString("dataset_version");
    apply.m_etag = response.GetHeader("ETag");
    apply.m_body = body;
    GameInstance.GetDelaySystem(this.m_gi).DelayCallback(apply, 0.0);
  }

  // --- no network layer (RedHttpClient absent) -----------------------------------------

  // Nothing to fetch: whatever LoadCache read is all the data this session will ever have.
  @if(!ModuleExists("RedHttpClient"))
  public func DoFetch() -> Void {
    let svc = NCZoningService.Get();
    if !IsDefined(svc) {
      return;
    }
    if svc.IsReady() {
      svc.SetStatusReason(NCZ_REASON_OFFLINE_SNAPSHOT());   // stale forever; nothing can revalidate it
      NCZoningLog(s"RedHttpClient not installed; serving \(svc.GetLocationCount()) locations from the manual snapshot (permanently stale)");
      return;
    }
    // LoadCache already recorded why (cache_missing / cache_invalid / storage_unavailable).
    NCZoningLog(s"RedHttpClient not installed and no usable locations_full.json (\(svc.GetStatusReason()))");
    this.ReportNoData(svc.GetStatusReason());
  }

  // --- shared -------------------------------------------------------------------------

  // Runs on the game thread (via NCZApplyResult). Safe to swap the store and touch state.
  public func ApplyResult(r: ref<NCZApplyResult>) -> Void {
    let svc = NCZoningService.Get();
    if !IsDefined(svc) {
      NCZoningLog("apply: NCZoningService missing");
      return;
    }
    if r.m_error {
      // Retries exhausted. Degrade quietly if the cache is still serving; otherwise the player
      // has no data and the only fix is a manual download, so say so.
      svc.SetStatusReason(r.m_reason);
      if svc.IsReady() {
        NCZoningDataEvent.Dispatch(n"NCZoning-DataError", svc.GetDataVersion(), svc.GetLocationCount(), r.m_reason);
        NCZoningApi.NotifyDataError(r.m_reason);
        NCZoningLog(s"DataError dispatched (\(r.m_reason)); still serving \(svc.GetLocationCount()) cached locations");
      } else {
        NCZoningLog(s"DataError dispatched (\(r.m_reason)); no data available");
        this.ReportNoData(r.m_reason);
      }
      return;
    }
    if r.m_notModified {
      svc.SetStale(false);                       // cache confirmed current by the server
      svc.SetStatusReason("");
      NCZoningLog("cache confirmed current (304)");
      return;
    }
    // 200: swap the store and persist, then signal Ready (first) or Refreshed (subsequent).
    svc.SetStore(r.m_locations, r.m_datasetVersion, false);
    svc.WriteCache(r.m_body, r.m_etag, r.m_datasetVersion);
    let count = svc.GetLocationCount();
    if this.m_readyDispatched {
      NCZoningDataEvent.Dispatch(n"NCZoning-DataRefreshed", r.m_datasetVersion, count, "");
      NCZoningApi.NotifyDataReady(count, r.m_datasetVersion, true);
      NCZoningLog(s"store refreshed + cache written: \(count) locations, dataset=\(r.m_datasetVersion)");
    } else {
      NCZoningDataEvent.Dispatch(n"NCZoning-DataReady", r.m_datasetVersion, count, "");
      NCZoningApi.NotifyDataReady(count, r.m_datasetVersion, false);
      this.m_readyDispatched = true;
      NCZoningLog(s"store ready + cache written: \(count) locations, dataset=\(r.m_datasetVersion)");
    }
  }

  // No data and no way to get any. Signal consumers, then tell the player: the mod has no UI and
  // no CET, so an on-screen message is the only channel that reaches someone not reading logs.
  private func ReportNoData(reason: String) -> Void {
    NCZoningDataEvent.Dispatch(n"NCZoning-DataError", "", 0, reason);
    NCZoningApi.NotifyDataError(reason);
    this.m_pendingReason = reason;
    this.TryShowNoDataMessage();
  }

  public func OnHudReady() -> Void {
    this.m_hudReady = true;
    this.TryShowNoDataMessage();
  }

  private func TryShowNoDataMessage() -> Void {
    if this.m_messageShown || !this.m_hudReady || StrLen(this.m_pendingReason) == 0 {
      return;
    }
    this.m_messageShown = true;
    let msg = new NCZNoDataMessage();
    msg.m_gi = this.m_gi;
    msg.m_reason = this.m_pendingReason;
    GameInstance.GetDelaySystem(this.m_gi).DelayCallback(msg, 3.0);   // let the HUD intro settle
  }

  private func ScheduleRetry() -> Void {
    if this.m_retries >= 3 {
      NCZoningLog("fetch giving up after 3 retries");
      // Bounce a DataError to the game thread (event dispatch must not run on the worker).
      let err = new NCZApplyResult();
      err.m_fetcher = this;
      err.m_error = true;
      err.m_reason = NCZ_REASON_FETCH_FAILED();
      GameInstance.GetDelaySystem(this.m_gi).DelayCallback(err, 0.0);
      return;
    }
    this.m_retries += 1;
    let backoff = Cast<Float>(this.m_retries) * 2.0;   // 2s, 4s, 6s
    NCZoningLog(s"scheduling retry \(this.m_retries)/3 in \(backoff)s");
    let retry = new NCZRetry();
    retry.m_fetcher = this;
    GameInstance.GetDelaySystem(this.m_gi).DelayCallback(retry, backoff);
  }
}

// Carries the parsed result from the worker thread to the game thread. Call() runs on the
// game thread, where swapping NCZoningService's store is safe.
public class NCZApplyResult extends DelayCallback {
  public let m_fetcher: wref<NCZoningFetcher>;
  public let m_notModified: Bool;                     // true for a 304 (no payload)
  public let m_error: Bool;                           // true for a give-up -> dispatch DataError
  public let m_reason: String;
  public let m_locations: array<ref<NCZLocation>>;
  public let m_datasetVersion: String;
  public let m_etag: String;
  public let m_body: String;                          // raw response body, for the cache write

  public func Call() -> Void {
    if IsDefined(this.m_fetcher) {
      this.m_fetcher.ApplyResult(this);
    }
  }
}

// Re-arms a fetch on the game thread after a backoff delay.
public class NCZRetry extends DelayCallback {
  public let m_fetcher: wref<NCZoningFetcher>;

  public func Call() -> Void {
    if IsDefined(this.m_fetcher) {
      this.m_fetcher.DoFetch();
    }
  }
}

// "Loading finished, player is in the world." Must be a hook, not a timer: the WarningMessage
// blackboard slot is dropped unless WarningMessageGameController is already listening on it.
@wrapMethod(QuestTrackerGameController)
protected cb func OnInitialize() -> Bool {
  let result = wrappedMethod();
  let player = this.GetPlayerControlledObject();
  if IsDefined(player) {
    let fetcher = GameInstance.GetScriptableSystemsContainer(player.GetGame())
      .Get(n"NCZoning.Core.NCZoningFetcher") as NCZoningFetcher;
    if IsDefined(fetcher) {
      fetcher.OnHudReady();
    }
  }
  return result;
}

// The red "no location data" alert. WarningMessage is the alert slot that honours `duration`;
// OnscreenMessage is the cinematic-subtitle slot and fades on its own animation.
public class NCZNoDataMessage extends DelayCallback {
  public let m_gi: GameInstance;
  public let m_reason: String;

  public func Call() -> Void {
    let text: String;
    if UnicodeStringEqual(this.m_reason, NCZ_REASON_CACHE_INVALID()) {
      text = "NC Zoning: locations_full.json is unreadable. Re-download it - see the mod page.";
    } else {
      if NCZHttpAvailable() {
        text = "NC Zoning: could not download the location registry, and no local copy exists. See the mod page.";
      } else {
        text = "NC Zoning: no location data. Install RedHttpClient, or download locations_full.json by hand - see the mod page.";
      }
    }

    let msg: SimpleScreenMessage;
    msg.isShown = true;
    msg.duration = 8.0;                      // long enough to read three lines, short enough not to nag
    msg.message = text;
    msg.type = SimpleMessageType.Negative;   // -> Default state = red error styling
    GameInstance.GetBlackboardSystem(this.m_gi)
      .Get(GetAllBlackboardDefs().UI_Notifications)
      .SetVariant(GetAllBlackboardDefs().UI_Notifications.WarningMessage, ToVariant(msg), true);
  }
}
