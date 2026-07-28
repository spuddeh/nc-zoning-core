# Changelog

## 0.3.0 (pre-release)

- The registry cache file is renamed locations_full.json -> locations.json, and the fetch URL drops
  the retired ?full=1. Both encoded the API's old slim/full fork, which has been collapsed into one
  representation: the slim shape was built for a consumer that never existed (it dropped description,
  which the District Guide needs, and thumbnails, which the website needs) and both real consumers
  always asked for full.
  - ?full=1 survives as a NO-OP ALIAS, not a redirect. Worth being precise about: nothing was broken
    and nothing would have broken - RedHttpClient never had to follow a 301, the parameter was simply
    ignored. It is dropped because it describes a distinction the API no longer has.
  - THE RENAME IS A BREAKING CHANGE AND THE WINDOW FOR IT CLOSES AT 1.0.0. Players hand-place this
    file when they decline RedHttpClient, so the name is part of the user-facing contract. Doing it
    now costs nothing because the mod has never been published; after 1.0.0 it would need a migration
    read of the old name rather than a rename.
  - The filename is now a single NCZ_LocationsFile() rather than three string literals, so the next
    change is one edit and cannot go half-done.
  - Existing dev instances still hold the old file in overwrite\. With RedHttpClient installed it
    simply re-fetches; without it, the old file must be renamed by hand or the mod reports
    cache_missing.
- Documented a one-click refresh for MO2 users: curl registered as an MO2 executable and run from the
  dropdown. MO2 runs it inside the same virtual filesystem as the game, so the file lands in
  overwrite\ exactly as if the mod had written it - the same location already documented, automated
  rather than added to. --create-dirs is required: on a fresh install the storage folder does not
  exist until the mod first runs. It is a convenience, NOT a substitute for RedHttpClient - the mod
  still reports a permanent snapshot, because it has no clock and cannot tell a file fetched a minute
  ago from one fetched in March.

- Installed-mod detection. NCZLocation now parses the API's `archives` array (v1.5.0+, the
  .archive/.xl filenames a location mod installs; 285 of 297 live records carry one), and a new
  NCZInstalledRegistry answers which registry locations are actually present on this machine.
  Public surface: IsInstallDetectionAvailable(), GetInstallState(loc), GetInstalledCount(), plus
  NCZoningApi.GetInstallStateInt(id) for CET Lua consumers.
  - THREE STATES, and Unknown is a real answer rather than a rounding error. It means either
    detection did not run, or the location cannot be detected at all. An empty archives array is
    NOT "not installed": it is an AMM mod, whose files live in CET's own sandboxed folder where
    no mod can see them, or a record the API has not filled yet - and those are indistinguishable
    from in-game. Collapsing Unknown into NotInstalled would tell players to download mods they
    already own. NCZInstallState.Unknown is the zero value so an unpopulated registry says so.
  - This is why the mod now ships Lua at all, and it is the ONLY Lua it ships. Detection means
    reading archive/pc/mod/, and nothing reachable from redscript can: RedFileSystem confines
    every mod to r6/storages/<name>/, and the string "Archive" does not occur anywhere in the
    RTTI dump. CET's ModArchiveExists is the only route (measured true/false 2026-07-28). The
    bundled CET component scans on data-ready and pushes ids back through
    BeginInstallScan/ReportInstalled/EndInstallScan.
  - CET REMAINS OPTIONAL TO THE FRAMEWORK. Without it the component never runs, the registry
    stays empty, IsInstallDetectionAvailable() is false and everything reads Unknown. Redscript
    consumers never touch Lua.
  - Results are in-memory and per-session, deliberately never persisted: install state is
    precisely what changes between sessions, so a cached answer goes stale in the one direction
    that matters - claiming a mod is present after it was removed.
  - The write path uses STATIC methods called with a dot, matching the one CET interop idiom this
    codebase has actually verified, and pushes ids ONE AT A TIME - marshalling an array<String>
    across the CET boundary is the fragile part, a few hundred String calls are not.
  - NCZInstallState lives in NCZoning.Data, not NCZoning.Core: consumers must be able to name it
    and they never import Core, and redscript requires a return type to be imported even when it
    is never written out.

- RedLogger is now a HARD dependency, and the NCZoningLog wrapper's call sites SHIP. The
  wrapper body changed from FTLog to RedLog.Append("NCZoningCore", ...); its 19 call sites
  were untouched, which is the whole reason a wrapper existed. Logs land in
  r6\logs\mods\NCZoningCore__<date_time>.log - one file per session, five kept, oldest pruned.
  Taken deliberately despite forcing the dependency onto every consumer of the framework: the
  usual failure report against a background framework is "the registry never loaded", which is
  answerable only from a log, and a consumer can now be asked for one small file scoped to
  this mod rather than a shared log or a special debug build.
  Why this may ship where Log/LogChannel may not: those need a per-mod Logs.reds carrying a
  `native func` declaration, and redscript compiles every installed mod into ONE unit, so two
  mods each shipping one is a duplicate declaration that breaks every redscript mod on the
  player's machine. RedLogger's signature ships once, inside the plugin, so the collision is
  structurally impossible however many mods call it. Logs.reds is still never shipped.
  RedLog.Append has no level parameter, so log levels must be encoded in the line text.
  examples/RedscriptConsumer.reds and docs/consumer-guide.md updated to teach the same shape;
  the example's guard on NCZoning.Api is sufficient rather than lucky, because Core cannot
  compile without RedLogger, so a resolvable NCZoning.Api implies RedLogger is installed.

- Added the district vocabulary API: GetDistricts() and GetSubdistricts(district) enumerate the
  registry's district and subdistrict names from the static Layer-1 NCZDistrictMap, so a consumer can
  build a complete area picker (areas with zero locations included) without deriving it from the
  location list. Exposed on both the redscript NCZoning.Api surface and the CET NCZoningApi facade.
- Added GetStatusMessage(): a human-readable one-line status string, complementing the
  machine-readable GetStatusReason().
- Added recently_updated to NCZLocation (RecentlyUpdated() accessor). The /v1 API now ships a
  server-computed per-location recency boolean - the polyfill for the missing in-game clock, so a
  consumer can flag mods updated within the API's recency window with no date math. Read via RedData
  GetKeyBool in FromJsonObject; additive and non-breaking (an older Core build ignores the new key and
  the field defaults to false), so ApiVersion() is unchanged (stays 1). The envelope's
  recently_updated_days window is deliberately not consumed - Core reads the bool, it does not compute
  recency.

## 0.2.0 (pre-release)

- RedHttpClient is now a SOFT dependency. NCZoningCore compiles and runs without it. Every
  reference to it, the import included, is behind @if(ModuleExists("RedHttpClient")), which
  redscript evaluates before name resolution, so the absent module is not an UNRESOLVED_IMPORT.
  Verified by compiling the mod with scc against the real dependency scripts both with and
  without RedHttpClient installed (and confirming that an ungated import does fail).
  This answers a user concern about installing a general-purpose HTTP plugin: with RedHttpClient
  removed, the mod has no networking component at all, rather than merely declining to use one.
- Without RedHttpClient the registry is read from a locations_full.json the user downloads by
  hand into r6\storages\NCZoningCore\, and is served as permanently stale data. Deliberately NOT
  shipping a bundled snapshot: this mod updates rarely, so a bundled copy would go stale and
  hand users bad data with no signal. README and the Nexus description carry the curl command.
- Added a status-reason system, so "no data" is legible instead of silent. NCZoningService now
  records why it has no live data: offline_snapshot, fetch_failed, cache_missing, cache_invalid,
  or storage_unavailable ("" means live). Exposed as GetStatusReason() and IsHttpAvailable() on
  both the redscript API and the CET Lua facade. Read alongside IsReady(): a reason with
  IsReady() == true is informational, with IsReady() == false it is fatal for the session.
- Added an on-screen error when the mod has no registry data and no way to obtain any (no
  locations_full.json and either no RedHttpClient or a failed download). This is the framework's
  only UI, and exists because otherwise every consumer mod would silently look broken for a reason
  the user could not discover. It uses the UI_Notifications WarningMessage slot with
  SimpleMessageType.Negative, which is what renders the red error styling (Neutral renders blue;
  there is no Warning member in that enum). WarningMessage is the real warning popup and honours
  the duration, unlike the OnscreenMessage slot (the cinematic-subtitle channel, which fades on
  its own animation). Timing
  is driven by a QuestTrackerGameController.OnInitialize hook, the established "loading finished"
  marker, plus a 3s settle: the blackboard slot only displays if the warning controller is already
  listening, so this cannot be a plain timer.
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
