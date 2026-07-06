# Changelog

## 0.1.0 (pre-release)

- Initial scaffold of the NCZoningCore framework mod (flat pure-redscript layout,
  no source/packed split, no WolvenKit project).
- Added the NCZoning.Data DTOs (NCZLocation and the response envelope) matching
  the frozen /v1 API contract, including per-location district / subdistrict.
- Added the NCZoningDataEvent payload for the three data lifecycle events.
- Added the internal NCZoning.Core service with the in-memory store plus location
  query methods (id, category, tag, district, subdistrict, near-position).
- Decided against consuming /v1/districts: the game resolves the player's district
  natively (DistrictManager) and each location already carries its classification.
- Added the public NCZoning.Api surface (Version and ApiVersion handshake, ready
  and stale status, dataset version, and query forwarders).
- Added NCZoningFetcher: on session start it fetches /v1/locations?full=1 once per
  launch, parses on the HTTP worker thread, then bounces to the game thread via the
  DelaySystem before swapping the live store. Retries three times with backoff.
  (Verified in-game populating 291 locations from the live API.)
- Added the offline-first RedFileSystem cache: a fresh (200) payload and its ETag are
  written to locations_full.json + meta.json; on the next launch the cache is parsed and
  served immediately (marked stale until confirmed), then a conditional GET with
  If-None-Match revalidates. A 304 clears the stale flag with no re-download.
  (Verified in-game: cold launch writes the cache; warm launch loads it and gets a 304.)
- Added the public lifecycle events NCZoning-DataReady / NCZoning-DataRefreshed /
  NCZoning-DataError (Codeware CallbackSystem, for redscript consumers), carrying dataset
  version, count, and an error reason. Confirmed the frozen event names deliver as typed
  events in-game.
- Added the CET Lua bridge: a bare-named NCZoningApi facade (read-only static methods) that
  Lua consumers call directly (NCZoningApi.GetAllLocations() etc.), plus an Observe-able
  OnDataReady instance hook for the data-ready signal. Added examples/ for both a redscript
  soft-dependency consumer and a CET Lua consumer. Verified in-game from Lua (reads, array
  iteration, DTO methods, and the Observe notification).
