// ======================================================================================
// Mod Name: NCZoningCore
// File: NCZoningApi.reds
// Author: Spuddeh
// Description: NCZoningApi - the CET Lua-facing facade. Declared with NO module so its
//              RTTI name stays bare ("NCZoningApi"), which is what CET Lua reaches:
//              reads as static calls (NCZoningApi.GetAllLocations()), and the data-ready
//              signal as an Observe-able instance method (Observe('NCZoningApi','OnDataReady')).
//              A ScriptableService so it has a singleton for the instance hook. Read-only
//              forwarders to the internal service; redscript consumers use `import NCZoning.Api.*`.
// Mod Version: 1.1.0
// Credits: psiberx (Codeware)
// ======================================================================================

import NCZoning.Core.*
import NCZoning.Data.*
import NCZoning.Api.*

public class NCZoningApi extends ScriptableService {
  public static func Get() -> ref<NCZoningApi> {
    return GameInstance.GetScriptableServiceContainer().GetService(n"NCZoningApi") as NCZoningApi;
  }

  // --- version handshake (static; Lua: NCZoningApi.Version()) -------------------
  public static func Version() -> String { return "1.1.0"; }
  public static func ApiVersion() -> Int32 { return 1; }

  // --- status ------------------------------------------------------------------
  public static func IsReady() -> Bool {
    let s = NCZoningService.Get();
    return IsDefined(s) && s.IsReady();
  }
  public static func IsStale() -> Bool {
    let s = NCZoningService.Get();
    return IsDefined(s) && s.IsStale();
  }
  public static func GetDataVersion() -> String {
    let s = NCZoningService.Get();
    if IsDefined(s) { return s.GetDataVersion(); }
    return "";
  }
  public static func GetLocationCount() -> Int32 {
    let s = NCZoningService.Get();
    if IsDefined(s) { return s.GetLocationCount(); }
    return 0;
  }
  // False when the build has no RedHttpClient, so the registry can never refresh itself.
  public static func IsHttpAvailable() -> Bool { return NCZHttpAvailable(); }
  // "" when live; otherwise offline_snapshot / cache_missing / cache_invalid /
  // storage_unavailable / fetch_failed. Pair with IsReady(): + true is informational, + false is fatal.
  public static func GetStatusReason() -> String {
    let s = NCZoningService.Get();
    if IsDefined(s) { return s.GetStatusReason(); }
    return "";
  }
  // The player-facing sentence for the current state; "" when live. Show it INSTEAD of a zero
  // count when IsReady() is false: a zero count and no-data must not look the same.
  public static func GetStatusMessage() -> String {
    return NCZStatusMessage(NCZoningApi.GetStatusReason());
  }

  // --- district vocabulary (static; Lua: NCZoningApi.GetDistricts()) -------------
  // Every district/subdistrict name the registry can attribute a location to, A-Z. Generated
  // from /v1/districts, so unlike the queries below these do not depend on the fetch: they
  // answer before the data lands and while it is missing.
  //
  // Build a district picker from these, not from GetAllLocations() - an area with zero locations
  // exists here but appears in no location.
  public static func GetDistricts() -> array<String> {
    return NCZDistrictMap.AllDistricts();
  }
  // Empty for a district with no subdistricts (Dogtown, NCX Spaceport / Morro Rock) or an unknown
  // one. A district total is NOT the sum of its subdistricts - some locations are attributed to the
  // district directly. Use GetLocationsByDistrict for a district total.
  public static func GetSubdistricts(district: String) -> array<String> {
    return NCZDistrictMap.SubdistrictsOf(district);
  }

  // --- location queries --------------------------------------------------------
  public static func GetAllLocations() -> array<ref<NCZLocation>> {
    let out: array<ref<NCZLocation>>;
    let s = NCZoningService.Get();
    if IsDefined(s) { out = s.GetAllLocations(); }
    return out;
  }
  public static func GetLocationById(id: String) -> ref<NCZLocation> {
    let s = NCZoningService.Get();
    if IsDefined(s) { return s.GetLocationById(id); }
    return null;
  }
  public static func GetLocationsByDistrict(district: String) -> array<ref<NCZLocation>> {
    let out: array<ref<NCZLocation>>;
    let s = NCZoningService.Get();
    if IsDefined(s) { out = s.GetLocationsByDistrict(district); }
    return out;
  }
  public static func GetLocationsBySubdistrict(subdistrict: String) -> array<ref<NCZLocation>> {
    let out: array<ref<NCZLocation>>;
    let s = NCZoningService.Get();
    if IsDefined(s) { out = s.GetLocationsBySubdistrict(subdistrict); }
    return out;
  }
  public static func GetLocationsByCategory(category: String) -> array<ref<NCZLocation>> {
    let out: array<ref<NCZLocation>>;
    let s = NCZoningService.Get();
    if IsDefined(s) { out = s.GetLocationsByCategory(category); }
    return out;
  }
  public static func GetLocationsByTag(tag: String) -> array<ref<NCZLocation>> {
    let out: array<ref<NCZLocation>>;
    let s = NCZoningService.Get();
    if IsDefined(s) { out = s.GetLocationsByTag(tag); }
    return out;
  }
  public static func GetLocationsNear(pos: Vector4, radius: Float) -> array<ref<NCZLocation>> {
    let out: array<ref<NCZLocation>>;
    let s = NCZoningService.Get();
    if IsDefined(s) { out = s.GetLocationsNear(pos, radius); }
    return out;
  }

  // The recency window in days, from the response envelope. Per-record recency is on the
  // location itself (loc:RecentlyUpdated()); this is the number behind it, for UI text.
  public static func GetRecencyWindowDays() -> Int32 {
    let s = NCZoningService.Get();
    if IsDefined(s) { return s.GetRecencyWindowDays(); }
    return 7;
  }

  // --- installed-mod detection: READ ONLY, in both directions -------------------
  //
  // The scan runs in redscript against RedFunctions and needs nothing pushed in, so Lua reads
  // the result the same way it reads everything else. BeginInstallScan / ReportInstalled /
  // EndInstallScan are gone with the CET component that called them.

  // Returns the enum as Int32 (0 Unknown / 1 Installed / 2 NotInstalled), since Lua has no
  // enum type.
  public static func GetInstallStateInt(id: String) -> Int32 {
    let r = NCZInstalledRegistry.Get();
    let s = NCZoningService.Get();
    if !IsDefined(r) || !IsDefined(s) {
      return EnumInt(NCZInstallState.Unknown);
    }
    return EnumInt(r.StateOf(s.GetLocationById(id)));
  }

  public static func IsInstallDetectionAvailable() -> Bool {
    let r = NCZInstalledRegistry.Get();
    return IsDefined(r) && r.IsAvailable();
  }

  // --- CET Lua data-ready hook (INSTANCE method, so it can be Observed) ---------
  // No-op that exists to be Observed from CET Lua (custom CallbackSystem events dispatched
  // via DispatchEventAs are NOT delivered to Lua, and Observe only hooks instance methods):
  //   Observe('NCZoningApi', 'OnDataReady', function(self, count, datasetVersion, isRefresh) ... end)
  public func OnDataReady(count: Int32, datasetVersion: String, isRefresh: Bool) -> Void {}

  // Same shape for the failure path, when the registry could not be obtained at all:
  //   Observe('NCZoningApi', 'OnDataError', function(self, reason) ... end)
  // `reason` matches GetStatusReason().
  public func OnDataError(reason: String) -> Void {}

  // Null-safe entries the fetcher calls (game thread) -> fan out to the Observe-able hooks.
  public static func NotifyDataReady(count: Int32, datasetVersion: String, isRefresh: Bool) -> Void {
    let self = NCZoningApi.Get();
    if IsDefined(self) {
      self.OnDataReady(count, datasetVersion, isRefresh);
    }
  }

  public static func NotifyDataError(reason: String) -> Void {
    let self = NCZoningApi.Get();
    if IsDefined(self) {
      self.OnDataError(reason);
    }
  }
}
