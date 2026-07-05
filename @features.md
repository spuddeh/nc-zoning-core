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
- Offline-first RedFileSystem cache: writes the payload + ETag on a 200, loads and
  serves the cache on the next launch (stale until revalidated), then a conditional
  GET (If-None-Match) revalidates; a 304 clears stale with no re-download.
  (Verified in-game across a cold launch and a warm launch.)
- In-memory registry queries: all locations, by id, by category, by tag, by
  district, by subdistrict, and near a world position.
- Public NCZoning.Api surface with a Version (semver) and ApiVersion (breaking
  change handshake) plus ready, stale, and dataset-version status.
- Public lifecycle events dispatched via Codeware's CallbackSystem under the frozen
  names NCZoning-DataReady, NCZoning-DataRefreshed, and NCZoning-DataError (consumable
  from redscript and CET Lua), carrying dataset version, count, and an error reason.
  Dispatched on the game thread after the DelaySystem bounce. (Verified in-game.)

## Planned

- CET Lua bridge examples and consumer documentation (soft-dep, events, threading).
- v1.0 Nexus release against the /v1 contract.
