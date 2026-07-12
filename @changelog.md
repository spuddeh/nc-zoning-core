# Changelog

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
