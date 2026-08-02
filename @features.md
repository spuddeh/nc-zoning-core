# Features

## Shipping

- Nothing yet (pre-release).

## Implemented

- NCZLocation data model matching the frozen /v1 API contract, including the
  full-entry fields (description, credits, image URLs) and the per-location
  district / subdistrict classification.
- Once-per-launch fetch of /v1/locations over HTTPS (NCZoningFetcher):
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
  names NCZoning-DataReady, NCZoning-DataRefreshed, NCZoning-DataError and
  NCZoning-InstallScanComplete (for redscript consumers), carrying dataset version,
  count, and an error reason. Dispatched on the game thread after the DelaySystem
  bounce. (Verified in-game.)
- CET Lua bridge: a bare-named NCZoningApi facade with read-only static reads and an
  Observe-able OnDataReady hook, so CET Lua mods consume the registry directly. Worked
  examples in examples/ (redscript soft-dep consumer + CET Lua consumer). (Verified in-game.)
- RedLogger as a hard dependency, with the log calls shipping rather than stripped: one file
  per session at r6\logs\mods\NCZoningCore__<date_time>.log, five kept. Consumers of
  NCZoningCore inherit the requirement. (Verified in-game: file written, per-line timestamps, five
  sessions retained, no collision with NCZoningDistrictGuide or RCF.)
- Installed-mod detection, via a bundled CET Lua component: parses the API's archives field and
  answers Installed / NotInstalled / Unknown per location. (Verified in-game: 10 installed of 291
  tested, from 297 records. The 6 untested are the API's 5 AMM entries and 1 WIP, which carry no
  archive names and cannot be detected.)
- RedHttpClient as a soft dependency: the mod compiles and runs with the plugin absent, in which
  case it has no networking component at all and reads the registry from a hand-supplied
  locations.json. Every RedHttpClient reference, the import included, is gated behind
  @if(ModuleExists("RedHttpClient")). (Verified by compiling both ways with scc, and in-game:
  295 locations served from a manual snapshot with the plugin uninstalled, consumed normally by
  the NC Zoning District Guide.)
- Status reasons (offline_snapshot, fetch_failed, cache_missing, cache_invalid,
  storage_unavailable) surfaced through GetStatusReason() and IsHttpAvailable() on both the
  redscript API and the CET Lua facade, so a consumer can distinguish "usable but frozen data"
  from "no data is coming this session" instead of rendering an empty registry.
- On-screen error when the mod has no data and no way to get any: a SimpleScreenMessage on the
  UI_Notifications blackboard telling the user how to fix it. The framework's only UI.
- NCZoningApi.OnDataError Observe hook for CET Lua, mirroring OnDataReady.
- District vocabulary enumeration: GetDistricts() and GetSubdistricts(district) list the registry's
  area names (empty areas included) from the static Layer-1 map, on both the redscript and CET surfaces,
  plus GetStatusMessage() for a human-readable status line.
- Per-location recency: RecentlyUpdated() exposes the /v1 API's server-computed recently_updated
  boolean, so consumers can flag recently-updated mods without an in-game clock.

## Planned

- Release pipeline.
- v1.0 Nexus release against the /v1 contract.
