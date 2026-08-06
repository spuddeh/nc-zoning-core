# Changelog

## [Unreleased] - 1.1.0

Prepared, not released. Core and the District Guide ship together, and one further Guide feature is
still to land.

### Added

- Nineteen language slots under `translations/`, all empty but English, each wired into
  `Provider.reds`. A translation replaces one slot file and ships as its own mod, so anyone can
  publish one without a release here. Empty rather than English-seeded: a package fills after the
  English fallback, so a copied string would override newer English wording.
- `NCZoningCore.card.json` - category, description and the Nexus header image (1300x372) for RCF
  2.1.0's Big UI picker. Read by `DVRCF_Cards`, which is language-blind.
- `docs/TRANSLATING.md`.

### Changed

- `NCZoningLog` writes through `RedLog.AppendLevel`, and `NCZoningWarn` / `NCZoningError` join it.
  Twelve of twenty-one call sites re-levelled: degraded-but-still-serving is WARN, the session
  cannot do the thing at all is ERROR. Needs RedLogger 1.2.0+.
- RedLogger floor raised to 1.3.0 across README, the consumer guide and the Nexus description. Set
  by RCF 2.1.0 rather than by this mod - `ModuleExists` reports presence and never a version, so an
  older RedLogger beside RCF 2.1.0 fails the whole redscript compile.
- `release.yml`: `archive_existing_version` is false. A superseded file belongs in OLD FILES, which
  stays downloadable; archived does not.
- Vault wikilinks removed from shipped source. Redscript ships as plaintext and the vault has no
  remote, so they resolved for nobody who downloaded the mod.

## 1.0.0 - 2026-08-05

First public release, on Nexus and GitHub together with NC Zoning Board - District Guide 1.0.0.
The 0.x sections below are the pre-release development history; none of them shipped.

- Public title: "NC Zoning Board - Core". Folder, module, storage and log names stay
  `NCZoningCore`.
- Localisation via Codeware for the four status sentences (see 0.3.0 below - landed after the
  0.3.0 heading was cut but before any release).

## 0.3.0 (pre-release)

- Localisation via Codeware's ModLocalizationPackage: the four status sentences
  (GetStatusMessage / the no-data banner) now live as NCZ.* keys in translations/English.reds,
  resolved for the game's language with English as the fallback. Adding a language is one
  translated file plus one case in translations/Provider.reds. The cache filename is a {file}
  placeholder substituted from NCZ_LocationsFile(), so a translation cannot pin the old name.

- Removed NCZLocation.Source(), its backing field and its parse line, and the row that published it
  in the consumer guide's accessor table. The API dropped `source` in 0.5.0 - it was derived, stamped
  `manual` onto mods.json entries and `auto` onto Nexus ones at build time, and nothing auto-publishes
  now. `GetKeyString` on an absent key yields "", so the accessor answered "" for every location while
  the guide promised one of two values; a consumer branching on `Source() == "manual"` took the false
  path everywhere, silently. Provenance still reads off the id: a `nexus-` prefix is what `auto` meant.
  - ApiVersion() stays at 1. It gates a published contract, and this accessor never reached a release.

- Renamed the registry cache file locations_full.json -> locations.json, and dropped ?full=1 from
  the fetch URL. The API collapsed its slim/full split into one representation, so ?full=1 is now
  a no-op alias and the name no longer describes anything.
  - This is a breaking change, and the window for it closes at 1.0.0. Players hand-place this file
    when they decline RedHttpClient, so the name is part of the user-facing contract. After 1.0.0
    it needs a migration read of the old name rather than a rename.
  - The filename is now a single NCZ_LocationsFile() rather than three string literals.
  - Existing dev instances still hold the old file in overwrite\. With RedHttpClient installed the
    mod re-fetches; without it, rename the old file by hand or the mod reports cache_missing.
- Documented a one-click refresh for MO2 users: curl registered as an MO2 executable and run from
  the dropdown. MO2 runs it inside the same virtual filesystem as the game, so the file lands in
  overwrite\ where the mod would have written it. --create-dirs is required, because on a fresh
  install the storage folder does not exist until the mod first runs. This is a convenience, not a
  substitute for RedHttpClient: the mod still reports a permanent snapshot, having no clock to
  judge the file's age with.

- Installed-mod detection. NCZLocation now parses the API's `archives` array (v1.5.0+, the
  .archive/.xl filenames a location mod installs; 285 of 297 live records carry one), and a new
  NCZInstalledRegistry answers which registry locations are present on this machine.
  Public surface: IsInstallDetectionAvailable(), GetInstallState(loc), GetInstalledCount(), plus
  NCZoningApi.GetInstallStateInt(id) for CET Lua consumers.
  - Three states, and Unknown is a real answer. It means detection did not run, or the location
    cannot be detected at all: an empty archives array is either an AMM mod, whose files sit in
    CET's own sandboxed folder where no mod can see them, or a record the API has not filled yet.
    Those two are indistinguishable in game, so both read Unknown. NCZInstallState.Unknown is the
    zero value, so an unpopulated registry answers it by default.
  - This is why the mod ships Lua, and it is the only Lua it ships. Detection means reading
    archive/pc/mod/, which nothing reachable from redscript can do: RedFileSystem confines every
    mod to r6/storages/<name>/, and the string "Archive" does not occur anywhere in the RTTI dump.
    CET's ModArchiveExists is the only route. The bundled CET component scans on data-ready and
    pushes ids back through BeginInstallScan / ReportInstalled / EndInstallScan.
  - CET stays optional to the framework. Without it the component never runs, the registry stays
    empty, IsInstallDetectionAvailable() is false and everything reads Unknown. Redscript
    consumers never touch Lua.
  - Results are in-memory and per-session, never persisted. Install state is what changes between
    sessions, so a cached answer would claim a mod is present after it was removed.
  - The write path uses static methods called with a dot, and pushes ids one at a time. Passing an
    array<String> across the CET boundary is the fragile part of this route; a few hundred String
    calls are not.
  - NCZInstallState lives in NCZoning.Data, not NCZoning.Core: consumers must be able to name it
    and they never import Core, and redscript requires a return type to be imported even when it
    is never written out.

- RedLogger is now a hard dependency, and the NCZoningLog wrapper's call sites ship. The wrapper
  body changed from FTLog to RedLog.Append("NCZoningCore", ...); its 19 call sites were untouched.
  Logs land in r6\logs\mods\NCZoningCore__<date_time>.log - one file per session, five kept,
  oldest pruned. Every consumer of the framework inherits the dependency.
  - Safe to ship where Log/LogChannel are not: those need a per-mod Logs.reds carrying a
    `native func` declaration, and redscript compiles every installed mod into one unit, so two
    mods each shipping one is a duplicate declaration that breaks every redscript mod on the
    player's machine. RedLogger's signature ships once, inside the plugin, so callers cannot
    collide. Logs.reds is still never shipped.
  - RedLog.Append has no level parameter, so log levels are encoded in the line text.
  - examples/RedscriptConsumer.reds and docs/consumer-guide.md updated to the same shape. The
    example's @if guard on NCZoning.Api covers RedLogger too, because Core cannot compile without
    RedLogger, so a resolvable NCZoning.Api implies RedLogger is installed.

- Added the district vocabulary API: GetDistricts() and GetSubdistricts(district) enumerate the
  registry's district and subdistrict names from the static Layer-1 NCZDistrictMap, so a consumer can
  build a complete area picker (areas with zero locations included) without deriving it from the
  location list. Exposed on both the redscript NCZoning.Api surface and the CET NCZoningApi facade.
- Added GetStatusMessage(): a human-readable one-line status string, complementing the
  machine-readable GetStatusReason().
- Added recently_updated to NCZLocation (RecentlyUpdated() accessor). The /v1 API ships a
  server-computed per-location recency boolean, so a consumer can flag recently-updated mods
  without date maths that in-game code has no clock for. Read via RedData GetKeyBool in
  FromJsonObject; additive and non-breaking (an older Core build ignores the new key and the field
  defaults to false), so ApiVersion() stays 1. The envelope's recently_updated_days window is not
  consumed: Core reads the bool, it does not compute recency.

## 0.2.0 (pre-release)

- RedHttpClient is now a soft dependency. NCZoningCore compiles and runs without it, and with the
  plugin removed the mod has no networking component at all. Every reference to it, the import
  included, is behind @if(ModuleExists("RedHttpClient")), which redscript evaluates before name
  resolution, so the absent module is not an UNRESOLVED_IMPORT. Verified by compiling the mod
  with scc against the real dependency scripts both with and without RedHttpClient installed, and
  by confirming that an ungated import does fail.
- Without RedHttpClient the registry is read from a locations_full.json the user downloads by
  hand into r6\storages\NCZoningCore\, and is served as permanently stale data. No bundled
  snapshot is shipped: this mod updates rarely, so a bundled copy would go stale and hand users
  bad data with no signal. README and the Nexus description carry the curl command.
- Added a status-reason system, so "no data" is legible instead of silent. NCZoningService now
  records why it has no live data: offline_snapshot, fetch_failed, cache_missing, cache_invalid,
  or storage_unavailable ("" means live). Exposed as GetStatusReason() and IsHttpAvailable() on
  both the redscript API and the CET Lua facade. Read alongside IsReady(): a reason with
  IsReady() == true is informational, with IsReady() == false it is fatal for the session.
- Added an on-screen error when the mod has no registry data and no way to obtain any (no
  locations_full.json and either no RedHttpClient or a failed download). This is the framework's
  only UI. It uses the UI_Notifications WarningMessage slot with SimpleMessageType.Negative,
  which renders the red error styling (Neutral renders blue; there is no Warning member in that
  enum). WarningMessage is the warning popup and honours the duration, unlike the OnscreenMessage
  slot, which is the cinematic-subtitle channel and fades on its own animation. Timing is driven
  by a QuestTrackerGameController.OnInitialize hook, the "loading finished" marker, plus a 3s
  settle: the blackboard slot only displays if the warning controller is already listening, so
  this cannot be a plain timer.
- Added the NCZoningApi.OnDataError Observe hook for CET Lua consumers, mirroring OnDataReady and
  carrying the same reason string. The redscript NCZoning-DataError event now also fires when
  there was never any data to begin with, not only when a fetch failed.
- Consumer guide: documented the no-network path, the reason codes, and the trap it creates for
  consumers (a naive IsReady() poll never terminates for a user with no data and no RedHttpClient).

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
- Added docs/consumer-guide.md: the full consumer reference (requirements, redscript and CET
  Lua consumption, the data model, how the Lua bridge works, threading), with claims verified
  against the source or cited to upstream.
