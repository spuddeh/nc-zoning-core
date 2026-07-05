# Features

## Shipping

- Nothing yet (pre-release).

## Implemented

- NCZLocation data model matching the frozen /v1 API contract, including the
  full-entry fields (description, credits, image URLs) and the per-location
  district / subdistrict classification.
- Once-per-launch fetch of /v1/locations?full=1 over HTTPS (NCZoningFetcher):
  parse on the HTTP worker thread, DelaySystem bounce to the game thread, then
  swap the live store. Retries three times with backoff. (Verified in-game.)
- In-memory registry queries: all locations, by id, by category, by tag, by
  district, by subdistrict, and near a world position.
- Public NCZoning.Api surface with a Version (semver) and ApiVersion (breaking
  change handshake) plus ready, stale, and dataset-version status.
- NCZoningDataEvent carrying dataset version, count, and an error reason.

## Planned

- Conditional GET with If-None-Match / ETag (304 handling) once the cache lands.
- Offline-first RedFileSystem cache with ETag revalidation and a stale flag.
- Dispatch of NCZoning-DataReady, NCZoning-DataRefreshed, and NCZoning-DataError,
  with the worker-thread to game-thread bounce via DelaySystem.
- CET Lua bridge examples and consumer documentation (soft-dep, events, threading).
- v1.0 Nexus release against the /v1 contract.
