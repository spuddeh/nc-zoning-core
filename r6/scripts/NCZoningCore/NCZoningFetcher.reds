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
    this.DoFetch();
  }

  // Runs on the game thread (Session/Ready, or a retry bounce). Public so NCZRetry can call it.
  public func DoFetch() -> Void {
    let url = "https://api.nczoning.net/v1/locations?full=1";
    // M3 will add If-None-Match: <cached -full etag> here for conditional GET / 304.
    let callback = HttpCallback.Create(this, n"OnHttpResponse");
    AsyncHttpClient.Get(callback, url);
    NCZoningLog(s"fetch started: \(url)");
  }

  // HTTP callback - runs on a RED4ext JobQueue WORKER thread (Invariant #1). Parse only
  // here (pure data, no game state); hand the result to the game thread via DelaySystem.
  private cb func OnHttpResponse(response: ref<HttpResponse>) -> Void {
    if !IsDefined(response) || !Equals(response.GetStatus(), HttpStatus.OK) {
      let code = 0;
      if IsDefined(response) {
        code = response.GetStatusCode();
      }
      NCZoningLog(s"fetch failed (status \(code))");
      this.ScheduleRetry();
      return;
    }

    let obj = ParseJson(response.GetText()) as JsonObject;
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

    let datasetVersion = obj.GetKeyString("dataset_version");
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

    // Bounce to the game thread before touching the live store (Invariant #1).
    let apply = new NCZApplyResult();
    apply.m_fetcher = this;
    apply.m_locations = locs;
    apply.m_datasetVersion = datasetVersion;
    GameInstance.GetDelaySystem(this.m_gi).DelayCallback(apply, 0.0);
  }

  // Runs on the game thread (via NCZApplyResult). Safe to swap the store and touch state.
  public func ApplyResult(locations: array<ref<NCZLocation>>, datasetVersion: String) -> Void {
    let svc = NCZoningService.Get();
    if !IsDefined(svc) {
      NCZoningLog("apply: NCZoningService missing");
      return;
    }
    svc.SetStore(locations, datasetVersion, false);
    NCZoningLog(s"store updated on game thread: \(ArraySize(locations)) locations, dataset=\(datasetVersion)");
    // M4 will dispatch NCZoning-DataReady / NCZoning-DataRefreshed here.
  }

  private func ScheduleRetry() -> Void {
    if this.m_retries >= 3 {
      NCZoningLog("fetch giving up after 3 retries");
      // M4 will dispatch NCZoning-DataError here.
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
  public let m_locations: array<ref<NCZLocation>>;
  public let m_datasetVersion: String;

  public func Call() -> Void {
    if IsDefined(this.m_fetcher) {
      this.m_fetcher.ApplyResult(this.m_locations, this.m_datasetVersion);
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
