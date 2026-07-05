// ======================================================================================
// Mod Name: NCZoningCore
// File: NCZLocation.reds
// Author: Spuddeh
// Description: NCZoning.Data DTOs - typed classes RedData.FromJson deserializes the
//              /v1 API payload into. Field names mirror the JSON keys EXACTLY, because
//              RedData matches keys case-sensitively with no snake_case transform.
// Mod Version: 0.1.0 (Pre-release)
// Credits: psiberx (RedData, RedFileSystem, RedHttpClient, Codeware)
// ======================================================================================

module NCZoning.Data

import RedData.Json.*

// Whole /v1/locations?full=1 response, deserialized in a single FromJson call.
// array<ref<T>> is supported by RedData. If the whole-response bind fails during the
// M1 parse spike, fall back to: ParseJson(body) -> GetKey("data") as JsonArray ->
// FromJson(item, n"NCZoning.Data.NCZLocation") per element.
public class NCZLocationsResponse {
  let schema: Int32;
  let generated_at: String;
  let dataset_version: String;
  let data: array<ref<NCZLocation>>;
}

// A single registry entry. Slim (/v1/locations) plus the full (?full=1) extras.
public class NCZLocation {
  // --- slim fields -------------------------------------------------------------
  let id: String;                 // UUID (manual) or "nexus-<id>" (auto); stable
  let name: String;
  let nexus_id: String;           // snake_case ON PURPOSE (case-sensitive bind); numeric / WIP / Dummy
  let coordinates: array<Float>;  // [X, Y, Z] raw CET world floats - NOT a Vector4; see Pos()
  let yaw: Float;                 // may be int / float / negative in JSON; Float binds all
  let category: String;           // location-overhaul | new-location | other
  let tags: array<String>;
  let authors: array<String>;
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
}

// A district (or subdistrict) from /v1/districts. centroid is a nested object
// (DTO-safe); boundary is a FLATTENED [x1,y1,x2,y2,...] array (no arrays-of-arrays).
public class NCZDistrict {
  let id: String;
  let name: String;
  let centroid: ref<NCZCentroid>;
  let boundary: array<Float>;
  let subdistricts: array<ref<NCZDistrict>>;  // same shape; canonical set on these
  let canonical: Bool;

  public func Id() -> String { return this.id; }
  public func Name() -> String { return this.name; }
  public func Boundary() -> array<Float> { return this.boundary; }
  public func Subdistricts() -> array<ref<NCZDistrict>> { return this.subdistricts; }
  public func IsCanonical() -> Bool { return this.canonical; }

  // Centroid on the ground plane (Z = 0, W = 1); zero vector if centroid is missing.
  public func CentroidPos() -> Vector4 {
    let v: Vector4;
    if IsDefined(this.centroid) {
      v.X = this.centroid.X();
      v.Y = this.centroid.Y();
      v.W = 1.0;
    }
    return v;
  }
}

// Whole /v1/districts response. Only the data array is captured; the envelope's
// schema / generated_at / dataset_version are read separately from the transport layer.
public class NCZDistrictsResponse {
  let data: array<ref<NCZDistrict>>;
}

public class NCZCentroid {
  let x: Float;
  let y: Float;

  public func X() -> Float { return this.x; }
  public func Y() -> Float { return this.y; }
}
