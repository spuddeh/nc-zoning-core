// ======================================================================================
// Mod Name: NCZoningCore
// File: NCZLocation.reds
// Author: Spuddeh
// Description: NCZoning.Data DTOs - typed classes RedData.FromJson deserializes the
//              /v1 API payload into. Field names mirror the JSON keys EXACTLY, because
//              RedData matches keys case-sensitively with no snake_case transform.
// Mod Version: 1.1.0
// Credits: psiberx (RedData, RedFileSystem, RedHttpClient, Codeware)
// ======================================================================================

module NCZoning.Data

import RedData.Json.*

// The /v1 response is parsed MANUALLY: ParseJson(body) -> GetKey("data") as JsonArray ->
// NCZLocation.FromJsonObject() per element (explicit field reads, no reflection). The
// envelope's dataset_version is read from the ETag response header (or GetKeyString on the
// cached envelope).

// Whether a location's mod is present in archive/pc/mod/ on this machine.
//
// Part of the public contract, so it lives here rather than beside the registry that fills it:
// consumers must be able to name it and they never import NCZoning.Core, and redscript requires
// a return type to be imported even when it is never written out.
//
// THREE STATES. Unknown means the scan has not run, or the location cannot be detected at all -
// an AMM mod ships no archive, and an ArchiveXL .xl is a manifest rather than a mounted archive,
// so neither can ever be matched. Do not render Unknown as "not installed". Unknown is the zero
// value, so an unpopulated registry answers it by default.
public enum NCZInstallState {
  Unknown = 0,
  Installed = 1,
  NotInstalled = 2,
}

// "YYYY-MM-DDTHH:MM:SSZ" -> Unix epoch seconds. Returns 0.0d for anything else.
//
// LENGTH-LOCKED TO 20 CHARACTERS, UTC, no offset and no fractional seconds - the one shape the
// API serves. An offset or a millisecond field would parse to a wrong instant rather than fail,
// so the shape is rejected outright instead of being guessed at.
//
// Returns Double, not Int32: epoch seconds pass Int32's ceiling in January 2038.
//
// The date arithmetic is days-from-civil, which is exact for every Gregorian date and needs no
// leap-year table - the /4, /100 and /400 terms ARE the leap rule. Verified against all 294
// dated records plus 2000-02-29, 2024-02-29, 2100-03-01 and the 2038 boundary.
public func NCZ_Iso8601ToEpoch(value: String) -> Double {
  if StrLen(value) != 20 {
    return 0.0d;
  }
  let y = StringToInt(StrMid(value, 0, 4), -1);
  let mo = StringToInt(StrMid(value, 5, 2), -1);
  let d = StringToInt(StrMid(value, 8, 2), -1);
  let h = StringToInt(StrMid(value, 11, 2), -1);
  let mi = StringToInt(StrMid(value, 14, 2), -1);
  let se = StringToInt(StrMid(value, 17, 2), -1);
  // The 1970 floor is not cosmetic: it keeps every division below positive, so truncation and
  // floor agree and the era term needs no negative-year branch.
  if y < 1970 || mo < 1 || mo > 12 || d < 1 || d > 31
      || h < 0 || h > 23 || mi < 0 || mi > 59 || se < 0 || se > 60 {
    return 0.0d;
  }

  // March-based year: February's length stops being a special case when it is the last month.
  let shifted = y;
  let mp = mo - 3;
  if mo <= 2 {
    shifted -= 1;
    mp = mo + 9;
  }
  let era = shifted / 400;
  let yoe = shifted - era * 400;                       // [0, 399]
  let doy = (153 * mp + 2) / 5 + d - 1;                // [0, 365]
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;     // [0, 146096]
  let days = era * 146097 + doe - 719468;              // 719468 = days from 0000-03-01 to 1970-01-01

  // Cast BEFORE multiplying. days * 86400 overflows Int32 from 2038 on.
  return Cast<Double>(days) * 86400.0d
       + Cast<Double>(h) * 3600.0d
       + Cast<Double>(mi) * 60.0d
       + Cast<Double>(se);
}

// A single registry entry. The API has one representation, so every field below arrives on
// every record from /v1/locations; there is no subset to ask for.
public class NCZLocation {
  // --- core fields -------------------------------------------------------------
  let id: String;                 // UUID (manual) or "nexus-<id>" (auto); stable
  let name: String;
  let nexus_id: String;           // snake_case ON PURPOSE (case-sensitive bind); numeric / WIP / Dummy
  let coordinates: array<Float>;  // [X, Y, Z] raw CET world floats - NOT a Vector4; see Pos()
  let yaw: Float;                 // may be int / float / negative in JSON; Float binds all
  let category: String;           // location-overhaul | new-location | other
  let tags: array<String>;        // built in FromJsonObject(); read via TagCount()/TagAt() or a local
  let authors: array<String>;     // built in FromJsonObject(); read via AuthorCount()/AuthorAt() or a local
  let district: String;           // never null (Badlands is the default region)
  let subdistrict: String;        // "" when the JSON value is null / key absent
  // --- richer fields (once behind ?full=1; always present since that split was dropped) ---
  let description: String;
  let credits: String;            // optional; "" when absent
  let thumbnail_url: String;
  let picture_url: String;
  let updated_at: String;         // nullable -> "" when absent
  let updated_at_epoch: Double;   // updated_at as Unix seconds; 0.0 when absent or malformed
  let recently_updated: Bool;     // recomputed against the live clock at store time; see RecentlyUpdated()
  // The .archive / .xl filenames this mod installs into archive/pc/mod/, for installed-mod
  // detection (API v1.5.0+). NOTHING MATCHABLE MEANS "CANNOT SAY", NEVER "NOT INSTALLED" - an
  // AMM mod, which ships no archive; a record listing only .xl manifests, which are not mounted
  // archives; or a record the API has not fetched yet. All read Unknown, and
  // DetectableArchiveCount() is the test, not ArraySize. See NCZInstallState.
  let archives: array<String>;

  // --- camelCase accessors (the public surface consumers read) -----------------
  public func Id() -> String { return this.id; }
  public func Name() -> String { return this.name; }
  public func NexusId() -> String { return this.nexus_id; }
  public func Yaw() -> Float { return this.yaw; }
  public func Category() -> String { return this.category; }
  // Bind the result to a `let` local before ArraySize/ArrayContains/indexing - see the
  // rvalue-array note on TagCount(); for a size or single element prefer TagCount()/TagAt().
  public func Tags() -> array<String> { return this.tags; }
  public func Authors() -> array<String> { return this.authors; }
  public func District() -> String { return this.district; }
  public func Subdistrict() -> String { return this.subdistrict; }
  public func Description() -> String { return this.description; }
  public func Credits() -> String { return this.credits; }
  public func ThumbnailUrl() -> String { return this.thumbnail_url; }
  public func PictureUrl() -> String { return this.picture_url; }
  // The raw ISO-8601 timestamp the API served, and the same instant as Unix seconds.
  //
  // UpdatedAtEpoch() is 0.0d when the API sent no date, or sent one that is not exactly
  // "YYYY-MM-DDTHH:MM:SSZ". Test for 0.0d before comparing: it means "no date", not 1970.
  public func UpdatedAt() -> String { return this.updated_at; }
  public func UpdatedAtEpoch() -> Double { return this.updated_at_epoch; }

  // True when the mod was updated within the recency window.
  //
  // Computed against the live clock when the store is built, so a cache loaded a fortnight later
  // answers for today rather than for the day it was written. Where no clock or no date is
  // available it keeps the bool the API served, which ages with the cache - see
  // NCZoningService.RecomputeRecency.
  //
  // The window is not per-record: read it from RecencyWindowDays().
  public func RecentlyUpdated() -> Bool { return this.recently_updated; }

  // Written by NCZoningService when it recomputes recency against the clock. Nothing else may
  // call this: two writers and the value depends on which ran last.
  public func SetRecentlyUpdated(value: Bool) -> Void { this.recently_updated = value; }

  // Raw CET coordinates as a Vector4 (W = 1). Returns the zero vector if the array
  // is malformed (fewer than 3 entries) rather than indexing out of bounds.
  public func Pos() -> Vector4 {
    let v: Vector4;
    if ArraySize(this.coordinates) >= 3 {
      v.X = this.coordinates[0];
      v.Y = this.coordinates[1];
      v.Z = this.coordinates[2];
      v.W = 1.0;
    }
    return v;
  }

  // Inline-safe count/index accessors. Prefer these when reading sizes or single elements:
  // applying ArraySize()/ArrayContains()/[] DIRECTLY to a method that returns an array reads
  // garbage in redscript (an rvalue-temporary bug). These return Int32/String, so they are
  // always safe inline.
  public func TagCount() -> Int32 { return ArraySize(this.tags); }
  public func TagAt(idx: Int32) -> String {
    if idx >= 0 && idx < ArraySize(this.tags) {
      return this.tags[idx];
    }
    return "";
  }
  public func AuthorCount() -> Int32 { return ArraySize(this.authors); }
  public func AuthorAt(idx: Int32) -> String {
    if idx >= 0 && idx < ArraySize(this.authors) {
      return this.authors[idx];
    }
    return "";
  }
  public func ArchiveCount() -> Int32 { return ArraySize(this.archives); }

  // How many of `archives` a mounted-archive query could ever match.
  //
  // An .xl is an ArchiveXL manifest, not a mounted archive, so it never appears in the
  // engine's archive list and no query can match it. A record whose archives are ALL .xl is
  // therefore undetectable in exactly the way a record with no archives at all is, and both
  // must read Unknown - saying NotInstalled tells the player to download a mod they have.
  //
  // The test is "is a .archive", not "is not a .xl": an unrecognised extension must fall out
  // as undetectable rather than be assumed matchable, because a wrong Unknown costs nothing
  // and a wrong NotInstalled is the lie this whole distinction exists to prevent.
  public func DetectableArchiveCount() -> Int32 {
    let n = 0;
    let i = 0;
    let total = ArraySize(this.archives);
    while i < total {
      if StrEndsWith(StrLower(this.archives[i]), ".archive") {
        n += 1;
      }
      i += 1;
    }
    return n;
  }
  public func ArchiveAt(idx: Int32) -> String {
    if idx >= 0 && idx < ArraySize(this.archives) {
      return this.archives[idx];
    }
    return "";
  }
  public func Archives() -> array<String> { return this.archives; }

  // Build an NCZLocation from one /v1 location element, by hand: new object plus explicit
  // GetKey* reads, no reflection.
  public static func FromJsonObject(item: ref<JsonObject>) -> ref<NCZLocation> {
    let loc = new NCZLocation();
    if !IsDefined(item) {
      return loc;
    }
    loc.id = item.GetKeyString("id");
    loc.name = item.GetKeyString("name");
    loc.nexus_id = item.GetKeyString("nexus_id");
    loc.yaw = Cast<Float>(item.GetKeyDouble("yaw"));
    loc.category = item.GetKeyString("category");
    loc.district = item.GetKeyString("district");
    loc.subdistrict = item.GetKeyString("subdistrict");
    loc.description = item.GetKeyString("description");
    loc.credits = item.GetKeyString("credits");
    loc.thumbnail_url = item.GetKeyString("thumbnail_url");
    loc.picture_url = item.GetKeyString("picture_url");
    loc.updated_at = item.GetKeyString("updated_at");
    loc.updated_at_epoch = NCZ_Iso8601ToEpoch(loc.updated_at);
    loc.recently_updated = item.GetKeyBool("recently_updated");

    let coords = item.GetKey("coordinates") as JsonArray;
    if IsDefined(coords) {
      let cn = coords.GetSize();
      let ci: Uint32 = 0u;
      while ci < cn {
        ArrayPush(loc.coordinates, Cast<Float>(coords.GetItemDouble(ci)));
        ci += 1u;
      }
    }
    loc.tags = NCZLocation.ReadStrArr(item, "tags");
    loc.authors = NCZLocation.ReadStrArr(item, "authors");
    // Additive since API v1.5.0. An older Core build ignored this key and an older API omits
    // it; both cases land as an empty array, which already means "cannot say".
    loc.archives = NCZLocation.ReadStrArr(item, "archives");
    return loc;
  }

  private static func ReadStrArr(item: ref<JsonObject>, key: String) -> array<String> {
    let out: array<String>;
    let arr = item.GetKey(key) as JsonArray;
    if !IsDefined(arr) {
      return out;
    }
    let n = arr.GetSize();
    let i: Uint32 = 0u;
    while i < n {
      ArrayPush(out, arr.GetItemString(i));
      i += 1u;
    }
    return out;
  }
}

// NOTE: there is no district-geometry DTO here, and there should not be one. Each NCZLocation
// already carries its server-computed district / subdistrict, and the game resolves the
// PLAYER's current district natively via DistrictManager.GetCurrentDistrict() and the
// gamedataDistrict enum, so the API's /v1/districts boundary polygons are not consumed.
// Consumers join "player's current district" (from the game) to a location's District() /
// Subdistrict() string, through the game-vocabulary -> API-string map in NCZoningDistricts.reds.
