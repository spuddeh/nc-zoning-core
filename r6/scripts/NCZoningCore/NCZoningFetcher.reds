// ======================================================================================
// Mod Name: NCZoningCore
// File: NCZoningFetcher.reds
// Author: Spuddeh
// Description: NCZoningFetcher - the network lifecycle. A ScriptableSystem (so it has
//              GetGameInstance() for the DelaySystem bounce, which a ScriptableService
//              lacks). On Session/Ready it fetches /v1/locations?full=1 once per game
//              launch, parses on the HTTP worker thread, then bounces to the game thread
//              via DelaySystem before swapping NCZoningService's live store. Retries x3.
// Mod Version: 0.1.0 (Pre-release)
// Credits: psiberx (Codeware), rayshader (RedHttpClient, RedData, RedFileSystem)
// ======================================================================================

module NCZoning.Core

import NCZoning.Data.*
import RedData.Json.*
import RedHttpClient.*

public class NCZoningFetcher extends ScriptableSystem {
  private let m_gi: GameInstance;   // captured on the game thread; used to arm the bounce
  private let m_done: Bool;         // one fetch per game launch (system persists across saves)
  private let m_retries: Int32;
  private let m_readyDispatched: Bool;   // NCZoning-DataReady fired once (cache load or first 200)

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
    // Offline-first: load the cache now (store becomes ready + stale), then revalidate.
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

  // Runs on the game thread (Session/Ready, or a retry bounce). Public so NCZRetry can call it.
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

  // Runs on the game thread (via NCZApplyResult). Safe to swap the store and touch state.
  public func ApplyResult(r: ref<NCZApplyResult>) -> Void {
    let svc = NCZoningService.Get();
    if !IsDefined(svc) {
      NCZoningLog("apply: NCZoningService missing");
      return;
    }
    if r.m_error {
      // All retries failed. Consumers can still check IsReady() (cache may be serving data).
      NCZoningDataEvent.Dispatch(n"NCZoning-DataError", svc.GetDataVersion(), svc.GetLocationCount(), r.m_reason);
      NCZoningLog(s"DataError dispatched (\(r.m_reason)); ready=\(svc.IsReady())");
      return;
    }
    if r.m_notModified {
      svc.SetStale(false);                       // cache confirmed current by the server
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

  private func ScheduleRetry() -> Void {
    if this.m_retries >= 3 {
      NCZoningLog("fetch giving up after 3 retries");
      // Bounce a DataError to the game thread (event dispatch must not run on the worker).
      let err = new NCZApplyResult();
      err.m_fetcher = this;
      err.m_error = true;
      err.m_reason = "fetch_failed";
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
