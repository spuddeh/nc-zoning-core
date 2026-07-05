// ======================================================================================
// Mod Name: NCZoningCore
// File: NCZoningService.reds
// Author: Spuddeh
// Description: NCZoningService - the internal ScriptableService that owns the
//              RedFileSystem storage and the in-memory registry store. NCZoning.Api
//              forwards to this singleton; consumers never import NCZoning.Core.
// Mod Version: 0.1.0 (Pre-release)
// Credits: psiberx (Codeware, RedFileSystem, RedData, RedHttpClient)
// ======================================================================================

module NCZoning.Core

import NCZoning.Data.*
import RedFileSystem.*

// Dev-only log wrapper. Codeware (a required dependency) provides FTLog globally, so no
// Logs.reds signature file is needed and there is no risk of a duplicate native-func
// clash. STRIP this wrapper and every call site before a Nexus release build (see the
// no-shipped-logging rule).
public func NCZoningLog(value: script_ref<String>) -> Void {
  FTLog(s"[NCZoningCore] \(value)");
}

public class NCZoningService extends ScriptableService {
  private let m_storage: ref<FileSystemStorage>;
  private let m_locations: array<ref<NCZLocation>>;
  private let m_ready: Bool;
  private let m_stale: Bool;
  private let m_datasetVersion: String;

  // --- lifecycle ---------------------------------------------------------------

  private cb func OnLoad() -> Void {
    // GetStorage is callable ONCE per session; cache the ref (a second call permanently
    // locks the storage). Name must match [A-Za-z]{3,24}: "NCZoningCore" is valid.
    this.m_storage = FileSystem.GetStorage("NCZoningCore");
    GameInstance.GetCallbackSystem()
      .RegisterCallback(n"Session/Ready", this, n"OnSessionReady")
      .SetLifetime(CallbackLifetime.Forever);
  }

  protected cb func OnSessionReady(event: ref<GameSessionEvent>) -> Void {
    let reqs = GameInstance.GetSystemRequestsHandler();
    if IsDefined(reqs) && reqs.IsPreGame() {
      return;
    }
    // M2 / M3 TODO:
    //  1. Async-load cached locations_full.json + meta.json from m_storage.
    //     Offline-first: if the cache parses, populate the store, set
    //     m_ready, set m_stale if fetched_at > 24h, and dispatch NCZoning-DataReady.
    //  2. Conditional GET /v1/locations?full=1 with If-None-Match: <stored -full etag>.
    //     304 -> touch timestamp; 200 -> read the ETag header, parse + build the array on
    //     the HTTP worker thread, write the cache async, then bounce via
    //     GetDelaySystem().DelayCallback(cb, 0.0) BEFORE swapping the live store and
    //     dispatching NCZoning-DataRefreshed. Retry x3 with backoff, then NCZoning-DataError.
    NCZoningLog("Session ready (skeleton: fetch and cache not yet implemented).");
  }

  public static func Get() -> ref<NCZoningService> {
    return GameInstance.GetScriptableServiceContainer()
      .GetService(n"NCZoning.Core.NCZoningService") as NCZoningService;
  }

  public func GetStorage() -> ref<FileSystemStorage> {
    return this.m_storage;
  }

  // --- status ------------------------------------------------------------------

  public func IsReady() -> Bool { return this.m_ready; }
  public func IsStale() -> Bool { return this.m_stale; }
  public func GetDataVersion() -> String { return this.m_datasetVersion; }

  // --- location queries (pure; operate on the in-memory store) -----------------

  public func GetAllLocations() -> array<ref<NCZLocation>> {
    return this.m_locations;
  }

  public func GetLocationById(id: String) -> ref<NCZLocation> {
    let i = 0;
    while i < ArraySize(this.m_locations) {
      if UnicodeStringEqual(this.m_locations[i].Id(), id) {
        return this.m_locations[i];
      }
      i += 1;
    }
    return null;
  }

  public func GetLocationsByCategory(category: String) -> array<ref<NCZLocation>> {
    let out: array<ref<NCZLocation>>;
    let i = 0;
    while i < ArraySize(this.m_locations) {
      if UnicodeStringEqual(this.m_locations[i].Category(), category) {
        ArrayPush(out, this.m_locations[i]);
      }
      i += 1;
    }
    return out;
  }

  public func GetLocationsByTag(tag: String) -> array<ref<NCZLocation>> {
    let out: array<ref<NCZLocation>>;
    let i = 0;
    while i < ArraySize(this.m_locations) {
      // Bind Tags() to a local FIRST: ArrayContains on an inline array-return reads garbage
      // in redscript (rvalue-array bug). See wiki learning redscript-arraysize-on-returned-array.
      let tags = this.m_locations[i].Tags();
      if ArrayContains(tags, tag) {
        ArrayPush(out, this.m_locations[i]);
      }
      i += 1;
    }
    return out;
  }

  // Registry locations whose server-computed district matches (e.g. "Watson"). The
  // consumer supplies the district in API vocabulary; joining to the player's live
  // district is the consumer's job (game DistrictManager + a small normalization map).
  public func GetLocationsByDistrict(district: String) -> array<ref<NCZLocation>> {
    let out: array<ref<NCZLocation>>;
    let i = 0;
    while i < ArraySize(this.m_locations) {
      if UnicodeStringEqual(this.m_locations[i].District(), district) {
        ArrayPush(out, this.m_locations[i]);
      }
      i += 1;
    }
    return out;
  }

  public func GetLocationsBySubdistrict(subdistrict: String) -> array<ref<NCZLocation>> {
    let out: array<ref<NCZLocation>>;
    let i = 0;
    while i < ArraySize(this.m_locations) {
      if UnicodeStringEqual(this.m_locations[i].Subdistrict(), subdistrict) {
        ArrayPush(out, this.m_locations[i]);
      }
      i += 1;
    }
    return out;
  }

  // Linear scan over ~300 entries (squared distance, no sqrt). Compares the full
  // 3D CET position against pos within radius.
  public func GetLocationsNear(pos: Vector4, radius: Float) -> array<ref<NCZLocation>> {
    let out: array<ref<NCZLocation>>;
    let r2 = radius * radius;
    let i = 0;
    while i < ArraySize(this.m_locations) {
      let p = this.m_locations[i].Pos();
      let dx = p.X - pos.X;
      let dy = p.Y - pos.Y;
      let dz = p.Z - pos.Z;
      if (dx * dx + dy * dy + dz * dz) <= r2 {
        ArrayPush(out, this.m_locations[i]);
      }
      i += 1;
    }
    return out;
  }
}
