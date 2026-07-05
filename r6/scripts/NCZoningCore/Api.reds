// ======================================================================================
// Mod Name: NCZoningCore
// File: Api.reds
// Author: Spuddeh
// Description: NCZoning.Api - the public contract. This is the ONLY module consumers
//              import. Every function is a thin, null-safe forwarder to the internal
//              NCZoningService singleton.
// Mod Version: 0.1.0 (Pre-release)
// Credits: psiberx (Codeware, RedFileSystem, RedData, RedHttpClient)
// ======================================================================================

module NCZoning.Api

import NCZoning.Core.*
import NCZoning.Data.*

// --- version handshake ---------------------------------------------------------
// redscript has no dependency versioning, and ModuleExists() cannot check a version,
// so this pair is the load-bearing contract. Version() is human-facing semver.
// ApiVersion() increments ONLY on a breaking change - never bump it silently.
public func Version() -> String { return "0.1.0"; }
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

// --- district queries ----------------------------------------------------------

public func GetAllDistricts() -> array<ref<NCZDistrict>> {
  let out: array<ref<NCZDistrict>>;
  let s = NCZoningService.Get();
  if IsDefined(s) {
    out = s.GetAllDistricts();
  }
  return out;
}

public func GetDistrictById(id: String) -> ref<NCZDistrict> {
  let s = NCZoningService.Get();
  if IsDefined(s) {
    return s.GetDistrictById(id);
  }
  return null;
}
