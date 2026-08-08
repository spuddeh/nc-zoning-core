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
- Levelled logging: NCZoningLog / NCZoningWarn / NCZoningError write through RedLog.AppendLevel,
  so the level is a tag RedLogger owns and RCF 2.1.0 colours on it - errors red, warnings amber -
  and its SHOWING filter selects on it. Needs RedLogger 1.2.0+; the stated floor is 1.3.0 because
  RCF 2.1.0 needs that much. (Verified in-game.)
- Installed-mod detection in pure redscript, over RedFunc.ArchiveExists: parses the API's archives
  field and answers Installed / NotInstalled / Unknown per location. RedFunctions is a hard
  dependency and CET is not involved. Re-scans when the store swaps, because the network payload can
  carry records the cache did not. (Verified in-game: 4 installed of 288 detectable from 295
  records, no false positives from the 10 mounted archives that are not registry locations. The 7
  undetectable are 5 AMM entries and 1 WIP id carrying no archive names, plus 1 record listing only
  an ArchiveXL .xl, which is a manifest rather than a mounted archive and can never be matched.)

- Shared archives excluded from detection: a file listed by locations from two different Nexus pages
  identifies none of them, so it is ignored and only files unique to one mod count. Two PAGES, not
  two records - one download can add two locations. Three names qualify today, reaching nine
  locations, all prop packs an author bundled instead of requiring. No location loses detection:
  every affected one also ships an archive of its own.
- Recency computed against a real clock: NCZ_Iso8601ToEpoch parses the API's updated_at and
  RecomputeRecency re-answers RecentlyUpdated() at every store swap, using the envelope's
  recently_updated_days as the window. A cache read weeks later answers for today rather than for
  the day it was written. (Verified in-game: 0 of 294 dated records differed from the API's own
  answer, on both a cache read and a fresh fetch.)
- updated_at, its parsed epoch and the recency window exposed to consumers - UpdatedAt(),
  UpdatedAtEpoch() and GetRecencyWindowDays() on the redscript API and the CET Lua facade - so a
  consumer can render "updated 3 days ago" rather than only "recent or not".
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
- Localised status sentences: the four player-facing strings resolve through Codeware's
  LocalizationSystem (translations/English.reds; English is the fallback for every language).
  Consumers reading GetStatusMessage() inherit the translation for free.
- Translation slots for all 19 game languages, each with a file and a Provider.reds case, empty but
  English. A translation REPLACES a slot file - same path, module and class - so it ships as its own
  mod and needs no release here. Those three names are public API from the first translation
  onward. See docs/TRANSLATING.md.
- RCF mod card (NCZoningCore.card.json): category, description (capped at 110 characters on load)
  and the Nexus header image at 1300x372, for RCF 2.1.0's Big UI picker. The Core registers no
  settings panel, so its card shows in the WIKI list rather than the settings picker. Unlike the
  translation slots, the card and the docs page are language-blind.
- NCZoningApi.OnDataError Observe hook for CET Lua, mirroring OnDataReady.
- Area names in the player's language: LocalizeArea(district, subdistrict) answers from the game's
  own District_Record, so 35 of the 36 areas are translated wherever Cyberpunk is and match the
  world map's wording. North Oaks Casino is the exception - a registry POI with no district record -
  and is the only area name carried in the translation slots.

- District vocabulary enumeration: GetDistricts() and GetSubdistricts(district) list the registry's
  area names (empty areas included) from the static Layer-1 map, on both the redscript and CET surfaces,
  plus GetStatusMessage() for a human-readable status line.
- Per-location recency: RecentlyUpdated() exposes the /v1 API's server-computed recently_updated
  boolean, so consumers can flag recently-updated mods without an in-game clock.

## Planned

- Release pipeline.
- v1.0 Nexus release against the /v1 contract.
