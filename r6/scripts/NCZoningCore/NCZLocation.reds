// ======================================================================================
// Mod Name: NCZoningCore
// File: NCZLocation.reds
// Author: Spuddeh
// Description: NCZoning.Data DTOs - typed classes RedData.FromJson deserializes the
//              /v1 API payload into. Field names mirror the JSON keys EXACTLY, because
//              RedData matches keys case-sensitively with no snake_case transform.
// Mod Version: 0.2.0 (Pre-release)
// Credits: psiberx (RedData, RedFileSystem, RedHttpClient, Codeware)
// ======================================================================================

module NCZoning.Data

import RedData.Json.*

// The /v1 response is parsed MANUALLY: ParseJson(body) -> GetKey("data") as JsonArray ->
// NCZLocation.FromJsonObject() per element (explicit field reads, no reflection). The
// envelope's dataset_version is read from the ETag response header (or GetKeyString on the
// cached envelope).

// A single registry entry. Slim (/v1/locations) plus the full (?full=1) extras.
public class NCZLocation {
  // --- slim fields -------------------------------------------------------------
  let id: String;                 // UUID (manual) or "nexus-<id>" (auto); stable
  let name: String;
  let nexus_id: String;           // snake_case ON PURPOSE (case-sensitive bind); numeric / WIP / Dummy
  let coordinates: array<Float>;  // [X, Y, Z] raw CET world floats - NOT a Vector4; see Pos()
  let yaw: Float;                 // may be int / float / negative in JSON; Float binds all
  let category: String;           // location-overhaul | new-location | other
  let tags: array<String>;        // built in FromJsonObject(); read via TagCount()/TagAt() or a local
  let authors: array<String>;     // built in FromJsonObject(); read via AuthorCount()/AuthorAt() or a local
  let source: String;             // manual | auto
  let district: String;           // never null (Badlands is the default region)
  let subdistrict: String;        // "" when the JSON value is null / key absent
  // --- full (?full=1) fields ---------------------------------------------------
  let description: String;
  let credits: String;            // optional; "" when absent
  let thumbnail_url: String;
  let picture_url: String;
  let updated_at: String;         // nullable -> "" when absent

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
  public func Source() -> String { return this.source; }
  public func District() -> String { return this.district; }
  public func Subdistrict() -> String { return this.subdistrict; }
  public func Description() -> String { return this.description; }
  public func Credits() -> String { return this.credits; }
  public func ThumbnailUrl() -> String { return this.thumbnail_url; }
  public func PictureUrl() -> String { return this.picture_url; }

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

  // Build an NCZLocation from one /v1 location element, fully manually (new object +
  // explicit GetKey* reads). Chosen for explicit control and no reflection dependency.
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
    loc.source = item.GetKeyString("source");
    loc.district = item.GetKeyString("district");
    loc.subdistrict = item.GetKeyString("subdistrict");
    loc.description = item.GetKeyString("description");
    loc.credits = item.GetKeyString("credits");
    loc.thumbnail_url = item.GetKeyString("thumbnail_url");
    loc.picture_url = item.GetKeyString("picture_url");
    loc.updated_at = item.GetKeyString("updated_at");

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

// NOTE: There is deliberately no district-geometry DTO here. Each NCZLocation already
// carries its server-computed district / subdistrict (the API mirrors the game's district
// rules), and the game resolves the PLAYER's current district natively and far more richly
// via DistrictManager.GetCurrentDistrict() + the gamedataDistrict enum. Fetching the API's
// /v1/districts boundary polygons to re-run point-in-polygon in-game would be a worse
// reimplementation of what the engine already does, so NCZoningCore does not consume it.
// Consumers join "player's current district" (from the game) to a location's District() /
// Subdistrict() string; a small game-vocabulary -> API-string normalization map lives with
// the district-guide demo, not in the core data model.
