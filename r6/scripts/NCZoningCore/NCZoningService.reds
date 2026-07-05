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
import RedData.Json.*

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
  private let m_etag: String;                 // last ETag (verbatim, incl. quotes + -full)

  // --- lifecycle ---------------------------------------------------------------

  private cb func OnLoad() -> Void {
    // GetStorage is callable ONCE per session; cache the ref (a second call permanently
    // locks the storage). Name must match [A-Za-z]{3,24}: "NCZoningCore" is valid.
    // The fetch + Session/Ready lifecycle live in NCZoningFetcher (a ScriptableSystem, so it
    // has GetGameInstance() for the DelaySystem bounce that a ScriptableService lacks).
    this.m_storage = FileSystem.GetStorage("NCZoningCore");
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
  public func GetEtag() -> String { return this.m_etag; }
  public func SetStale(stale: Bool) -> Void { this.m_stale = stale; }
  // Inline-safe count (field-internal ArraySize). Callers can use this instead of
  // ArraySize(GetAllLocations()) which would hit the rvalue-array bug.
  public func GetLocationCount() -> Int32 { return ArraySize(this.m_locations); }

  // --- offline cache (RedFileSystem) -------------------------------------------

  // Offline-first: parse the cached body into the store and load the ETag. Marks the store
  // ready but STALE (cache is unverified until the network confirms via 200/304). Returns
  // true if a usable cache was loaded. Runs on the game thread (called from Session/Ready).
  public func LoadCache() -> Bool {
    if !IsDefined(this.m_storage) {
      return false;
    }
    if !Equals(this.m_storage.Exists("locations_full.json"), FileSystemStatus.True) {
      return false;
    }
    let locFile = this.m_storage.GetFile("locations_full.json");
    if !IsDefined(locFile) {
      return false;
    }
    let body = locFile.ReadAsText();
    if StrLen(body) == 0 {
      return false;
    }
    let obj = ParseJson(body) as JsonObject;
    if !IsDefined(obj) {
      return false;
    }
    let dataArr = obj.GetKey("data") as JsonArray;
    if !IsDefined(dataArr) {
      return false;
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
    this.SetStore(locs, obj.GetKeyString("dataset_version"), true);   // stale until revalidated

    // Load the stored ETag (meta.json) so the next fetch can send If-None-Match.
    this.m_etag = "";
    if Equals(this.m_storage.Exists("meta.json"), FileSystemStatus.True) {
      let metaFile = this.m_storage.GetFile("meta.json");
      if IsDefined(metaFile) {
        let metaObj = metaFile.ReadAsJson() as JsonObject;
        if IsDefined(metaObj) {
          this.m_etag = metaObj.GetKeyString("etag");
        }
      }
    }
    return true;
  }

  // Persist a fresh (200) payload + its ETag. Called on the game thread (via the bounce).
  // Sync write of ~216 KB happens during the load screen; switch to AsyncFile if it hitches.
  public func WriteCache(body: String, etag: String, datasetVersion: String) -> Void {
    if !IsDefined(this.m_storage) {
      return;
    }
    let locFile = this.m_storage.GetFile("locations_full.json");
    if IsDefined(locFile) {
      locFile.WriteText(body);
    }
    let meta = new JsonObject();
    meta.SetKeyString("etag", etag);
    meta.SetKeyString("dataset_version", datasetVersion);
    let metaFile = this.m_storage.GetFile("meta.json");
    if IsDefined(metaFile) {
      metaFile.WriteJson(meta);
    }
    this.m_etag = etag;
  }

  // Swap the live store. Called by NCZoningFetcher ON THE GAME THREAD (via the DelaySystem
  // bounce) once a fetch or cache load produces new data - never from the HTTP worker
  // thread, so the read side (Api/queries) stays race-free. See Invariant #1.
  public func SetStore(locations: array<ref<NCZLocation>>, datasetVersion: String, stale: Bool) -> Void {
    this.m_locations = locations;
    this.m_datasetVersion = datasetVersion;
    this.m_stale = stale;
    this.m_ready = true;
  }

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
