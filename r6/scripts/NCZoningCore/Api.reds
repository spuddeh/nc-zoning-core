// ======================================================================================
// Mod Name: NCZoningCore
// File: Api.reds
// Author: Spuddeh
// Description: NCZoning.Api - the public contract. This is the ONLY module consumers
//              import. Every function is a thin, null-safe forwarder to the internal
//              NCZoningService singleton.
// Mod Version: 0.2.0 (Pre-release)
// Credits: psiberx (Codeware, RedFileSystem, RedData, RedHttpClient)
// ======================================================================================

module NCZoning.Api

import NCZoning.Core.*
import NCZoning.Data.*

// --- version handshake ---------------------------------------------------------
// redscript has no dependency versioning, and ModuleExists() cannot check a version,
// so this pair is the load-bearing contract. Version() is human-facing semver.
// ApiVersion() increments ONLY on a breaking change - never bump it silently.
public func Version() -> String { return "0.2.0"; }
public func ApiVersion() -> Int32 { return 1; }

// --- status --------------------------------------------------------------------

public func IsReady() -> Bool {
  let s = NCZoningService.Get();
  return IsDefined(s) && s.IsReady();
}

public func IsStale() -> Bool {
  let s = NCZoningService.Get();
  return IsDefined(s) && s.IsStale();
}

public func GetDataVersion() -> String {
  let s = NCZoningService.Get();
  if IsDefined(s) {
    return s.GetDataVersion();
  }
  return "";
}

// False when the build has no RedHttpClient, so the registry can never refresh: it serves only a
// locations_full.json the player supplied by hand, or nothing.
public func IsHttpAvailable() -> Bool { return NCZHttpAvailable(); }

// "" when live; otherwise offline_snapshot / cache_missing / cache_invalid / storage_unavailable /
// fetch_failed. Read with IsReady(): a reason + IsReady() == true is informational (usable data
// that cannot refresh); + IsReady() == false means no data is coming, so say so rather than
// rendering an empty result.
public func GetStatusReason() -> String {
  let s = NCZoningService.Get();
  if IsDefined(s) {
    return s.GetStatusReason();
  }
  return "";
}

// --- location queries ----------------------------------------------------------

public func GetAllLocations() -> array<ref<NCZLocation>> {
  let out: array<ref<NCZLocation>>;
  let s = NCZoningService.Get();
  if IsDefined(s) {
    out = s.GetAllLocations();
  }
  return out;
}

public func GetLocationById(id: String) -> ref<NCZLocation> {
  let s = NCZoningService.Get();
  if IsDefined(s) {
    return s.GetLocationById(id);
  }
  return null;
}

public func GetLocationsByCategory(category: String) -> array<ref<NCZLocation>> {
  let out: array<ref<NCZLocation>>;
  let s = NCZoningService.Get();
  if IsDefined(s) {
    out = s.GetLocationsByCategory(category);
  }
  return out;
}

public func GetLocationsByTag(tag: String) -> array<ref<NCZLocation>> {
  let out: array<ref<NCZLocation>>;
  let s = NCZoningService.Get();
  if IsDefined(s) {
    out = s.GetLocationsByTag(tag);
  }
  return out;
}

public func GetLocationsNear(pos: Vector4, radius: Float) -> array<ref<NCZLocation>> {
  let out: array<ref<NCZLocation>>;
  let s = NCZoningService.Get();
  if IsDefined(s) {
    out = s.GetLocationsNear(pos, radius);
  }
  return out;
}

// District filters over the registry, keyed by the API's district vocabulary. To answer
// "what is in the player's current district", pair these with the game's own
// DistrictManager.GetCurrentDistrict() (NCZoningCore does not fetch district geometry).
public func GetLocationsByDistrict(district: String) -> array<ref<NCZLocation>> {
  let out: array<ref<NCZLocation>>;
  let s = NCZoningService.Get();
  if IsDefined(s) {
    out = s.GetLocationsByDistrict(district);
  }
  return out;
}

public func GetLocationsBySubdistrict(subdistrict: String) -> array<ref<NCZLocation>> {
  let out: array<ref<NCZLocation>>;
  let s = NCZoningService.Get();
  if IsDefined(s) {
    out = s.GetLocationsBySubdistrict(subdistrict);
  }
  return out;
}
