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
public func Version() -> String { return "1.1.0"; }
public func ApiVersion() -> Int32 { return 1; }

// --- installed-mod detection (1.0.0+) --------------------------------------------
//
// Detection runs against RedFunctions, a hard dependency, so it is always possible.
// IsInstallDetectionAvailable() reports whether the scan has RUN: it answers false until the
// registry has loaded and the scan has swept it, and everything reads Unknown until then.
// NCZoning-InstallScanComplete is the signal that it has an answer.
//
// A consumer calling these must require NCZoningCore 1.0.0+: calling a function that does
// not exist is a COMPILE error that takes down every redscript mod on the machine.
public func IsInstallDetectionAvailable() -> Bool {
  let r = NCZInstalledRegistry.Get();
  return IsDefined(r) && r.IsAvailable();
}

// Unknown means either the scan has not run yet or the location cannot be detected at all -
// AMM location mods ship no archive, so there is nothing for a mounted-archive query to find.
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

// --- recency (1.1.0+) ------------------------------------------------------------
//
// The window the API applies, in days, from the response envelope. Per-record recency is
// NCZLocation.RecentlyUpdated(); this is the number behind it, for UI text such as
// "updated in the last 7 days". Defaults to 7 when the payload omits it.
//
// A consumer wanting "how long ago" rather than "recently or not" reads
// NCZLocation.UpdatedAtEpoch() and compares against RedFunc.RealTimestamp(). Both are Unix
// seconds as Double; an epoch of 0.0 means the API sent no usable date.
public func GetRecencyWindowDays() -> Int32 {
  let s = NCZoningService.Get();
  if !IsDefined(s) {
    return 7;
  }
  return s.GetRecencyWindowDays();
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

// --- area names in the player's language (1.1.0+) --------------------------------
// A district or subdistrict name from the registry is DATA, and it is published in English only.
// Render one straight onto a widget and every player reads English, whatever their game language.
//
// THE TRANSLATION COMES FROM THE GAME, NOT FROM A TABLE HERE. Cyberpunk already names all but one
// of these areas in each of its twelve languages, so this resolves the game's own district record
// and asks it. That is a smaller thing to maintain than 36 names in every language, and it makes
// the guide agree with the world map and the fast-travel screen, which a separate translation
// would drift from.
//
// LocalizedName() RETURNS A LocKey, NOT TEXT ("LocKey#10962"), and GetLocalizedText resolves it.
// The global resolver is correct here and NCZ_T is not: NCZ_T reads Codeware's provider table for
// this mod's own NCZ.* keys, and the base game's table is exactly what it cannot see (Loc.reds).
//
// `subdistrict` is "" to name the district itself. Pass the area you want named, not the area the
// player is standing in - naming Kabuki is LocalizeArea("Watson", "Kabuki").
//
// FALLS BACK TO THE REGISTRY'S OWN NAME whenever the game cannot answer. English is the honest
// answer for an area the game has never heard of, and a name the registry publishes after this
// build is exactly that.
public func LocalizeArea(district: String, subdistrict: String) -> String {
  let raw = StrLen(subdistrict) > 0 ? subdistrict : district;
  // Bind before ArraySize: measuring the call directly measures a temporary and answers 0.
  let ids = NCZDistrictMap.RecordIdsFor(district, subdistrict);
  let count = ArraySize(ids);
  if count <= 0 {
    return NCZAreaOwnName(raw);
  }
  // More than one id means the registry's name is a composite of the game's, and it is rebuilt
  // here in the player's language rather than translated as a phrase.
  let out = "";
  let i = 0;
  while i < count {
    let record = TweakDBInterface.GetDistrictRecord(ids[i]);
    if !IsDefined(record) {
      return NCZAreaOwnName(raw);
    }
    let part = GetLocalizedText(record.LocalizedName());
    // A district record CAN carry an empty name - the game's own map checks for this before
    // drawing the subdistrict line. An empty part would silently eat half a composite.
    if StrLen(part) <= 0 {
      return NCZAreaOwnName(raw);
    }
    out += i > 0 ? " / " + part : part;
    i += 1;
  }
  return out;
}

// The areas the game cannot name, which today is North Oaks Casino alone: the registry attributes
// locations to it, and it is a POI rather than a district, so no district record exists to ask.
//
// NCZ_T ECHOES THE KEY when the string is missing or Codeware has not bound yet, and a nav row
// reading "NCZ.area.northOaksCasino" is worse than one reading English. The echo is the signal
// that the lookup failed, so it is what selects the fallback.
func NCZAreaOwnName(raw: String) -> String {
  if UnicodeStringEqual(raw, "North Oaks Casino") {
    let key = "NCZ.area.northOaksCasino";
    let text = NCZ_T(key);
    return UnicodeStringEqual(text, key) ? raw : text;
  }
  return raw;
}
