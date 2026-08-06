// ======================================================================================
// Mod Name: NCZoningCore
// File: Api.reds
// Author: Spuddeh
// Description: NCZoning.Api - the public contract. This is the ONLY module consumers
//              import. Every function is a thin, null-safe forwarder to the internal
//              NCZoningService singleton.
// Mod Version: 1.1.0
// Credits: psiberx (Codeware, RedFileSystem, RedData, RedHttpClient)
// ======================================================================================

module NCZoning.Api

import NCZoning.Core.*
import NCZoning.Data.*

// --- version handshake ---------------------------------------------------------
// redscript has no dependency versioning and ModuleExists() cannot check a version, so this
// pair is the only version contract. Version() is human-facing semver. ApiVersion()
// increments ONLY on a breaking change - never bump it silently.
//
// There is no @if(FunctionExists). A consumer that calls a function added in a later core
// fails to COMPILE against an older one, which takes every redscript mod on that machine
// down with it. A consumer must require the core version that introduced what it calls.
public func Version() -> String { return "1.0.0"; }
public func ApiVersion() -> Int32 { return 1; }

// --- installed-mod detection (1.0.0+) --------------------------------------------
//
// Check IsInstallDetectionAvailable() BEFORE offering the player any installed/missing
// filter. Detection needs CET (nothing reachable from redscript can read archive/pc/mod/),
// so on a machine without it every record answers Unknown.
//
// A consumer calling these must require NCZoningCore 1.0.0+: calling a function that does
// not exist is a COMPILE error that takes down every redscript mod on the machine.
public func IsInstallDetectionAvailable() -> Bool {
  let r = NCZInstalledRegistry.Get();
  return IsDefined(r) && r.IsAvailable();
}

// Unknown means either detection never ran (no CET) or the location cannot be detected at all
// - AMM location mods ship only a .json into CET's own sandboxed folder, which no mod can read.
// Do not render Unknown as "not installed".
public func GetInstallState(loc: ref<NCZLocation>) -> NCZInstallState {
  let r = NCZInstalledRegistry.Get();
  if !IsDefined(r) {
    return NCZInstallState.Unknown;
  }
  return r.StateOf(loc);
}

public func GetInstalledCount() -> Int32 {
  let r = NCZInstalledRegistry.Get();
  return IsDefined(r) ? r.InstalledCount() : 0;
}

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
// locations.json the player supplied by hand, or nothing.
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

// The player-facing sentence for the current state; "" when live. The only copy of this wording
// - the core's no-data banner reads it too - so do not restate it in a consumer.
//
// Pair with IsReady():
//   IsReady() + a message -> informational (data is usable but can never refresh)
//   no IsReady() + a message -> fatal for the session; show it INSTEAD of a zero count.
public func GetStatusMessage() -> String {
  return NCZStatusMessage(GetStatusReason());
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

// --- district vocabulary -------------------------------------------------------
// Every district/subdistrict name the registry can attribute a location to, A-Z.
//
// STATIC (generated from /v1/districts), so unlike the queries above these do not depend on the
// fetch: they answer before the data lands and while it is missing. Build a district picker from
// these, not from GetAllLocations() - an area with zero locations exists here but appears in no
// location (NCX Spaceport / Morro Rock, Rattlesnake Creek, SoCal Border Crossing today).
public func GetDistricts() -> array<String> {
  return NCZDistrictMap.AllDistricts();
}

// Empty for a district with no subdistricts (Dogtown, NCX Spaceport / Morro Rock) or an unknown one.
// A district total is NOT the sum of its subdistricts - Badlands has 3 locations attributed to the
// district directly, inside no subdistrict. Use GetLocationsByDistrict for a district total.
public func GetSubdistricts(district: String) -> array<String> {
  return NCZDistrictMap.SubdistrictsOf(district);
}
