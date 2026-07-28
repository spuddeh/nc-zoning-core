// ======================================================================================
// Mod Name: NCZoningCore
// File: NCZoningService.reds
// Author: Spuddeh
// Description: NCZoningService - the internal ScriptableService that owns the
//              RedFileSystem storage and the in-memory registry store. NCZoning.Api
//              forwards to this singleton; consumers never import NCZoning.Core.
// Mod Version: 0.3.0 (Pre-release)
// Credits: psiberx (Codeware, RedFileSystem, RedData, RedHttpClient)
// ======================================================================================

module NCZoning.Core

import NCZoning.Data.*
import RedFileSystem.*
import RedData.Json.*
import RedLogger.*

// The log wrapper, and it SHIPS. RedLogger is a hard dependency (a bare import of an absent
// module does not compile), which is a deliberate choice for a framework: a consumer reporting
// "the registry never loaded" can be asked for one small file scoped to this mod alone, at
// r6/logs/mods/NCZoningCore__<date_time>.log.
//
// Why this is safe where Log/LogChannel are not: redscript compiles every installed mod into
// ONE unit, so the `native func` declaration a Logs.reds carries is global, and two mods each
// shipping one is a duplicate declaration that breaks every redscript mod on the machine.
// RedLogger's signature ships exactly once, inside the plugin, so the collision is
// structurally impossible however many mods call it. Logs.reds is still never shipped.
//
// RedLog.Append has no level parameter; encode any level in the line text.
// [[CP2077-Mods/wiki/decisions/redlogger-is-the-shipping-logging-path]]
public func NCZoningLog(value: script_ref<String>) -> Void {
  RedLog.Append("NCZoningCore", s"\(value)");
}

// The registry cache filename, in ONE place. It is part of the user-facing contract - players
// download it by hand when they decline RedHttpClient - so it appears in the README, the Nexus
// description and the curl command too. Changing it is a breaking change for anyone who has
// hand-placed the old one.
//
// Renamed from `locations.json` before 1.0.0 shipped, while there was still no installed
// base to break. The `_full` recorded the API's old slim/full split, which no longer exists.
// AFTER 1.0.0 this needs a migration read, not a rename.
public func NCZ_LocationsFile() -> String { return "locations.json"; }

// Values for GetStatusReason(); "" means live data. Public contract, like the event names:
// consumers compare against these, so additive only, never rename.
public func NCZ_REASON_OFFLINE_SNAPSHOT() -> String { return "offline_snapshot"; }   // no RedHttpClient; hand-supplied file, usable but stale forever
public func NCZ_REASON_CACHE_MISSING() -> String { return "cache_missing"; }         // no locations.json
public func NCZ_REASON_CACHE_INVALID() -> String { return "cache_invalid"; }         // present but empty / unparseable
public func NCZ_REASON_STORAGE_UNAVAIL() -> String { return "storage_unavailable"; } // RedFileSystem returned a null storage
public func NCZ_REASON_FETCH_FAILED() -> String { return "fetch_failed"; }           // retries exhausted; cache may still serve

// The player-facing sentence for a status reason; "" when live. Surfaced to consumers as
// NCZoning.Api.GetStatusMessage(). The only copy of this wording: the core's no-data banner and
// every consumer read it, so do not restate these sentences anywhere else.
public func NCZStatusMessage(reason: String) -> String {
  if StrLen(reason) == 0 {
    return "";                                       // live
  }
  // Usable data that can never refresh. Informational, not an error - IsReady() is true.
  if UnicodeStringEqual(reason, NCZ_REASON_OFFLINE_SNAPSHOT()) {
    return "NC Zoning: using a local snapshot. It cannot refresh without RedHttpClient.";
  }
  if UnicodeStringEqual(reason, NCZ_REASON_CACHE_INVALID()) {
    return "NC Zoning: locations.json is unreadable. Re-download it - see the mod page.";
  }
  if NCZHttpAvailable() {
    return "NC Zoning: could not download the location registry, and no local copy exists. See the mod page.";
  }
  return "NC Zoning: no location data. Install RedHttpClient, or download locations.json by hand - see the mod page.";
}

public class NCZoningService extends ScriptableService {
  private let m_storage: ref<FileSystemStorage>;
  private let m_locations: array<ref<NCZLocation>>;
  private let m_ready: Bool;
  private let m_stale: Bool;
  private let m_datasetVersion: String;
  private let m_etag: String;                 // last ETag (verbatim, incl. quotes + -full)
  private let m_statusReason: String;         // "" once live data is in hand; see NCZ_REASON_* above

  // --- lifecycle ---------------------------------------------------------------

  private cb func OnLoad() -> Void {
    // GetStorage is callable ONCE per session; cache the ref (a second call permanently
    // locks the storage). Name must match [A-Za-z]{3,24}: "NCZoningCore" is valid.
    // The fetch + Session/Ready lifecycle live in NCZoningFetcher (a ScriptableSystem, so it
    // has GetGameInstance() for the DelaySystem bounce that a ScriptableService lacks).
    this.m_storage = FileSystem.GetStorage("NCZoningCore");
    NCZoningDataEvent.RegisterNames();   // declare the public event names before anyone subscribes
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
  public func GetStatusReason() -> String { return this.m_statusReason; }
  public func SetStatusReason(reason: String) -> Void { this.m_statusReason = reason; }
  // Inline-safe count (field-internal ArraySize). Callers can use this instead of
  // ArraySize(GetAllLocations()) which would hit the rvalue-array bug.
  public func GetLocationCount() -> Int32 { return ArraySize(this.m_locations); }

  // --- offline cache (RedFileSystem) -------------------------------------------

  // Offline-first: parse the cached body into the store and load the ETag. Marks the store
  // ready but STALE (cache is unverified until the network confirms via 200/304). Returns
  // true if a usable cache was loaded. Runs on the game thread (called from Session/Ready).
  public func LoadCache() -> Bool {
    // Each early return records WHY, so the failure the player sees can distinguish "never
    // downloaded" from "downloaded but broken".
    if !IsDefined(this.m_storage) {
      this.m_statusReason = NCZ_REASON_STORAGE_UNAVAIL();
      return false;
    }
    if !Equals(this.m_storage.Exists(NCZ_LocationsFile()), FileSystemStatus.True) {
      this.m_statusReason = NCZ_REASON_CACHE_MISSING();
      return false;
    }
    let locFile = this.m_storage.GetFile(NCZ_LocationsFile());
    if !IsDefined(locFile) {
      this.m_statusReason = NCZ_REASON_CACHE_MISSING();
      return false;
    }
    let body = locFile.ReadAsText();
    if StrLen(body) == 0 {
      this.m_statusReason = NCZ_REASON_CACHE_INVALID();
      return false;
    }
    let obj = ParseJson(body) as JsonObject;
    if !IsDefined(obj) {
      this.m_statusReason = NCZ_REASON_CACHE_INVALID();
      return false;
    }
    let dataArr = obj.GetKey("data") as JsonArray;
    if !IsDefined(dataArr) {
      this.m_statusReason = NCZ_REASON_CACHE_INVALID();
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
  // This is a synchronous write of ~216 KB, and it lands during the load screen.
  public func WriteCache(body: String, etag: String, datasetVersion: String) -> Void {
    if !IsDefined(this.m_storage) {
      return;
    }
    let locFile = this.m_storage.GetFile(NCZ_LocationsFile());
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
  // thread, so the read side (Api/queries) stays race-free.
  public func SetStore(locations: array<ref<NCZLocation>>, datasetVersion: String, stale: Bool) -> Void {
    this.m_locations = locations;
    this.m_datasetVersion = datasetVersion;
    this.m_stale = stale;
    this.m_ready = true;
    this.m_statusReason = "";   // caller re-stamps an informational reason if one still applies
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
      // in redscript (rvalue-array bug).
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
