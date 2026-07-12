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
// Mod Version: 0.2.0 (Pre-release)
// Credits: psiberx (Codeware)
// ======================================================================================

import NCZoning.Core.*
import NCZoning.Data.*

public class NCZoningApi extends ScriptableService {
  public static func Get() -> ref<NCZoningApi> {
    return GameInstance.GetScriptableServiceContainer().GetService(n"NCZoningApi") as NCZoningApi;
  }

  // --- version handshake (static; Lua: NCZoningApi.Version()) -------------------
  public static func Version() -> String { return "0.2.0"; }
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
