// ======================================================================================
// Mod Name: NCZoningCore
// File: NCZLocation.reds
// Author: Spuddeh
// Description: NCZoning.Data DTOs - typed classes RedData.FromJson deserializes the
//              /v1 API payload into. Field names mirror the JSON keys EXACTLY, because
//              RedData matches keys case-sensitively with no snake_case transform.
// Mod Version: 0.3.0 (Pre-release)
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
// THREE STATES. Unknown means detection did not run (it needs CET; nothing reachable from
// redscript can read archive/pc/mod/) or the location cannot be detected at all - an AMM mod
// ships only a .json into CET's own sandboxed folder, which no mod can read. Do not render
// Unknown as "not installed". Unknown is the zero value, so an unpopulated registry answers it
// by default.
public enum NCZInstallState {
  Unknown = 0,
  Installed = 1,
  NotInstalled = 2,
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
  let recently_updated: Bool;     // server-computed; true when updated within the API's recency window
  // The .archive / .xl filenames this mod installs into archive/pc/mod/, for installed-mod
  // detection (API v1.5.0+). EMPTY MEANS "CANNOT SAY", NEVER "NOT INSTALLED" - it is either an
  // AMM mod, permanently undetectable because CET sandboxes its folder, or a record the API has
  // not fetched yet. Those two are indistinguishable from here, so both read Unknown. See
  // NCZInstallState.
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
  // Server-computed recency: true when the mod was updated within the API's recency window. The
  // window itself (recently_updated_days) rides the response envelope, not the record; consumers
  // read this bool rather than compute recency, since redscript has no wall clock.
  public func RecentlyUpdated() -> Bool { return this.recently_updated; }

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
