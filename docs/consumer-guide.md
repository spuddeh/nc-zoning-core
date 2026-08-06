# NCZoningCore Consumer Guide

How to build a mod on top of NCZoningCore, from either redscript or CET Lua.

NCZoningCore is a pure-redscript framework. It fetches the NC Zoning registry (an interactive
map of location mods at nczoning.net) once per game session, caches it offline-first, and
exposes it in game as a read-only API. Your mod reads that registry: each entry's name,
authors, world coordinates, category, tags, and district/subdistrict.

## Requirements

NCZoningCore itself needs, at runtime:

- RED4ext 1.29.0+, redscript 0.5.31+, and Cyberpunk 2077 2.31
- Codeware, RedData 0.9+, RedFileSystem 0.15+
- [RedLogger](https://www.nexusmods.com/cyberpunk2077/mods/31920) 1.3.0+
- RedHttpClient 0.7.1+, **optional** (see [When there is no network](#when-there-is-no-network))

**The 1.3.0 floor is set by the Redscript Configuration Framework, not by NCZoningCore.** RCF 2.1.0
calls RedLogger functions that 1.1.0 and 1.2.0 do not have, behind a guard that can only test whether
RedLogger is installed, not which build. A player with an older RedLogger and RCF 2.1.0 gets a
compile failure across every redscript mod on the machine. State 1.3.0+ in your own requirements too.

**RedLogger is a hard dependency, and it becomes one of yours too.** NCZoningCore imports it
unguarded, so anything depending on NCZoningCore inherits it - list it in your own
requirements. NCZoningCore logs through it, writing to
`r6\logs\mods\NCZoningCore__<date_time>.log`, one file per session with five kept.

You may log through it yourself as well. Unlike `Log` / `LogChannel`, a RedLogger call site is
safe to ship: those need a per-mod `Logs.reds` carrying a `native func` declaration, and
redscript compiles every installed mod into one unit, so two mods each shipping one is a
duplicate declaration that breaks *every* redscript mod on the player's machine. RedLogger's
signature ships once, inside the plugin, so callers cannot collide.
`examples/RedscriptConsumer.reds` shows the wrapper shape.

The Red\* dependencies are RED4ext plugins callable from redscript; each states RED4ext as its
own requirement, and RedData is what provides the JSON handling (see
[References](#references)). NCZoningCore calls no CET (Cyber Engine Tweaks) API and ships no Lua,
so **the framework does not require CET**. CET is required only by a consumer that is itself a CET
Lua mod (see [Consuming from CET Lua](#consuming-from-cet-lua)).

The files in `examples/` are documentation. They are not loaded by the framework.

## When is data available

One fetch runs per game launch. On session start NCZoningCore loads its offline cache
immediately (so the registry is usable within a second or two of entering the world, even with
no network), then revalidates over the network. Wait for a "data ready" signal rather than
assuming the data is present at startup. Both consumer types have a signal and a readiness
check, described below.

Status you can query at any time:

- `IsReady()` - the store is populated and queryable.
- `IsStale()` - the store was served from cache and has not yet been confirmed against the
  server this session (cleared once a network response confirms it).
- `GetDataVersion()` - the dataset content hash (changes when the registry changes).
- `IsHttpAvailable()` - whether this install can fetch at all (see below).
- `GetStatusReason()` - why the data is not live, if it is not.

## When there is no network

RedHttpClient is a **soft dependency**. Every reference to it in the source, the `import`
included, sits behind `@if(ModuleExists("RedHttpClient"))`, and redscript evaluates those
conditions before name resolution. With the plugin absent, that code is not compiled, so
NCZoningCore still builds and runs. It has no network layer.

That produces a session state that never resolves. A user without RedHttpClient supplies
`r6\storages\NCZoningCore\locations.json` by hand, and that file is all the data there will
ever be. If they have not supplied it, there is no data and no fetch coming. Do not sit in a
"waiting for data" state forever, and do not render an empty list as though the registry were
empty.

Three calls tell you where you are:

- `IsHttpAvailable() -> Bool` - false when the build has no network layer.
- `GetStatusMessage() -> String` - `""` when live; otherwise the player-facing sentence for the
  current state. **Show this instead of a zero count when `IsReady()` is false.** It is the only
  copy of that wording. Do not write your own version of these sentences.
- `GetStatusReason() -> String` - `""` when the data is live, otherwise one of:

| Reason | `IsReady()` | Meaning |
| --- | --- | --- |
| `offline_snapshot` | true | No RedHttpClient. Serving a hand-supplied file. Usable, permanently stale. |
| `fetch_failed` | either | Retries exhausted. If `IsReady()`, the cache is still serving. |
| `cache_missing` | false | No `locations.json`. No data at all. |
| `cache_invalid` | false | The file is present but empty or unparseable. |
| `storage_unavailable` | false | RedFileSystem returned a null storage. |

A reason with `IsReady() == true` is informational; one with `IsReady() == false` is fatal for
the session. In the fatal case NCZoningCore already shows the user an on-screen message
explaining how to fix it, so your mod does not need to repeat the install instructions.

**A zero count and no-data must not render the same.** "0 locations in this district" is a
resolved answer; "no location data" is a failure. Check `IsReady()` before you render any
count, and render `GetStatusMessage()` when it is false.

The fatal case also fires `NCZoning-DataError` (redscript) and `NCZoningApi.OnDataError` (CET
Lua), both carrying the same reason string.

## Consuming from redscript

Import the public module and call its free functions. `NCZoning.Api` is the only module a
consumer needs; `NCZoning.Data` provides the DTO and event payload types.

### Hard vs soft dependency

- Hard dependency: `import NCZoning.Api.*`. If NCZoningCore is absent, your mod fails to
  compile with an error naming the missing import. Simplest, but your mod will not load without
  NCZoningCore.
- Soft dependency: guard every top-level item that touches the API with
  `@if(ModuleExists("NCZoning.Api"))`. Those items compile to nothing when NCZoningCore is
  absent, so your mod still loads. redscript has no dependency versioning and `ModuleExists`
  cannot check a version, so also gate at runtime on `ApiVersion()`.

### Version handshake

- `Version() -> String` - human-facing semver.
- `ApiVersion() -> Int32` - increments only on a breaking change. Gate on it:
  `if ApiVersion() < 1 { return; }`.

**`ApiVersion()` does not protect you from an old core.** It is a runtime check, and the problem
lands at compile time. redscript has no `@if(FunctionExists)`, so if you call a function that a
later core added (`GetDistricts`, `GetSubdistricts`, `GetStatusMessage` - all 0.3.0) and the player
has an older NCZoningCore installed, the redscript compile fails. A redscript compile failure is
not local to your mod: it takes down **every** redscript mod on that machine.

`ModuleExists` guards the core being *absent*; nothing guards it being *stale*. If you call
anything added after 0.2.0, state a minimum NCZoningCore version in your requirements and mod page.

### Events

NCZoningCore dispatches these events through Codeware's CallbackSystem. Register with the frozen
names; the callback receives a `ref<NCZoningDataEvent>` (from `NCZoning.Data`):

```swift
let cs = GameInstance.GetCallbackSystem();
cs.RegisterCallback(n"NCZoning-DataReady", this, n"OnReady").SetLifetime(CallbackLifetime.Forever);
cs.RegisterCallback(n"NCZoning-DataRefreshed", this, n"OnRefreshed").SetLifetime(CallbackLifetime.Forever);
cs.RegisterCallback(n"NCZoning-DataError", this, n"OnError").SetLifetime(CallbackLifetime.Forever);

private cb func OnReady(event: ref<NCZoningDataEvent>) -> Void {
  // event.Count(), event.DatasetVersion()
}
```

- `NCZoning-DataReady` - the store first became usable this session (from cache or the first
  successful fetch).
- `NCZoning-DataRefreshed` - a later network fetch replaced the store with newer data.
- `NCZoning-DataError` - the registry could not be obtained. `event.Reason()` holds one of the
  codes in [When there is no network](#when-there-is-no-network); `IsReady()` may still be true
  if the offline cache is serving.
- `NCZoning-InstallScanComplete` - installed-mod detection has finished; `event.Count()` is how
  many locations are installed. Fires only when CET is present. Do not block on it.

If your system attaches after the event already fired, check `IsReady()` and use the data
directly.

### Query functions (all in `NCZoning.Api`)

| Function | Returns |
| --- | --- |
| `GetAllLocations()` | `array<ref<NCZLocation>>` |
| `GetLocationById(id: String)` | `ref<NCZLocation>` (null if absent) |
| `GetLocationsByDistrict(district: String)` | `array<ref<NCZLocation>>` |
| `GetLocationsBySubdistrict(subdistrict: String)` | `array<ref<NCZLocation>>` |
| `GetLocationsByCategory(category: String)` | `array<ref<NCZLocation>>` |
| `GetLocationsByTag(tag: String)` | `array<ref<NCZLocation>>` |
| `GetLocationsNear(pos: Vector4, radius: Float)` | `array<ref<NCZLocation>>` |

Status functions live in the same module: `IsReady()`, `IsStale()`, `GetDataVersion()`,
`IsHttpAvailable()`, `GetStatusReason()`, `GetStatusMessage()`.

### District vocabulary (0.3.0+)

| Function | Returns |
| --- | --- |
| `GetDistricts()` | `array<String>` - all 9 districts, A-Z |
| `GetSubdistricts(district: String)` | `array<String>` - that district's subdistricts, A-Z (empty for Dogtown and NCX Spaceport / Morro Rock, which have none) |

Both are on the CET facade too (`NCZoningApi.GetDistricts()`).

Building a district picker? Use these, **not** the districts you find on the locations. They are
static (generated from `/v1/districts`), so they need no network and no registry data: they answer
correctly before the fetch lands and while it is missing entirely.

Deriving the list from `GetAllLocations()` looks equivalent and is not. An area with zero locations
appears in no location, so it silently vanishes - today that is NCX Spaceport / Morro Rock,
Rattlesnake Creek and SoCal Border Crossing.

A district's total is **not** the sum of its subdistricts: some locations are attributed to a
district directly, inside no subdistrict (Badlands has 3). Use `GetLocationsByDistrict` for a
district total.

A full worked example is in [`examples/RedscriptConsumer.reds`](../examples/RedscriptConsumer.reds).

> Gotcha: never apply `ArraySize` / `ArrayContains` / index directly to one of these array
> returns inline; bind the result to a `let` local first. Applying an array intrinsic to a
> method's array return value reads garbage in redscript (an rvalue-temporary issue). This is a
> redscript-wide gotcha, not specific to NCZoningCore.

## Installed-mod detection

`GetInstallState(loc)` answers whether a location's mod is among the archives the engine has
mounted on this machine, as an `NCZInstallState`: `Unknown`, `Installed` or `NotInstalled`.

| Function | Returns |
| --- | --- |
| `IsInstallDetectionAvailable()` | `Bool` - false until a scan has completed |
| `GetInstallState(loc: ref<NCZLocation>)` | `NCZInstallState` |
| `GetInstalledCount()` | `Int32` |

CET Lua consumers use `NCZoningApi.GetInstallStateInt(id)`, which returns the enum as an
`Int32` (0 Unknown / 1 Installed / 2 NotInstalled).

Three rules for a consumer:

1. **Check `IsInstallDetectionAvailable()` before offering an installed/missing filter.** It is
   false until the scan has run, and every location answers `Unknown` until then. Subscribe to
   `NCZoning-InstallScanComplete` for the signal that it has an answer.
2. **Do not render `Unknown` as "not installed".** It means the scan has not run, or the
   location cannot be detected at all. Two kinds are permanently undetectable: an AMM location
   mod, which ships no `.archive`, and a mod that ships only ArchiveXL `.xl` files, which are
   manifests rather than mounted archives and so never appear in the archive list.
3. **A consumer calling these must require NCZoningCore 0.3.0+.** Calling a function that does
   not exist is a compile error, and that takes down every redscript mod on the machine.

## Consuming from CET Lua

CET Lua reaches NCZoningCore through a dedicated facade class, `NCZoningApi`. You do not import
anything; `NCZoningApi` is a global in CET Lua because CET exposes every redscript class through
the shared reflection system (see [How the CET Lua bridge works](#how-the-cet-lua-bridge-works)
and [References](#references)).

### Reading the registry

Call the facade's methods as statics (dot); call methods on a returned location with a colon.
A returned `array` arrives as a 1-indexed Lua table, so iterate with `ipairs`.

```lua
if NCZoningApi ~= nil and NCZoningApi.ApiVersion() >= 1 and NCZoningApi.IsReady() then
  print(NCZoningApi.GetLocationCount() .. " locations")

  local player = Game.GetPlayer()
  if player then
    for _, loc in ipairs(NCZoningApi.GetLocationsNear(player:GetWorldPosition(), 50.0)) do
      print(loc:Name() .. " by " .. loc:NexusId() .. " in " .. loc:District())
    end
  end

  local watson = NCZoningApi.GetLocationsByDistrict("Watson")
  print("Watson: " .. #watson .. " locations")
end
```

The Lua facade exposes the same reads as the redscript API, plus `GetLocationCount()`,
`IsHttpAvailable()`, and `GetStatusReason()`. It is read-only, so a Lua consumer cannot reach
the framework's internal mutating methods.

### Knowing when data is ready

Preferred: observe the framework's data-ready hook. NCZoningCore calls an instance method
`OnDataReady` on the game thread each time the store changes; observe it from Lua. The callback
arguments are `(self, count, datasetVersion, isRefresh)`:

```lua
Observe("NCZoningApi", "OnDataReady", function(_, count, datasetVersion, isRefresh)
  -- isRefresh is false on the first load, true on a later network refresh
  populateMyUI()
end)
```

Simpler alternative: poll `NCZoningApi.IsReady()` (for example in `onUpdate`) until it returns
true, then read once. This is fine for a one-time load.

Note: the CallbackSystem events in the redscript section are the redscript consumer path. Custom
CallbackSystem events dispatched from redscript are not delivered to CET Lua listeners, so Lua
uses the `Observe` hook above (or `IsReady()` polling).

### Knowing when data is never coming

`OnDataError` is the matching hook for the failure path. It receives the same reason string as
`GetStatusReason()`:

```lua
Observe("NCZoningApi", "OnDataError", function(_, reason)
  -- reason: cache_missing, cache_invalid, storage_unavailable, fetch_failed
  showMyOwnEmptyState(reason)
end)
```

If you poll `IsReady()` instead of observing, give the poll an exit. A user with no
RedHttpClient and no `locations.json` will never flip `IsReady()` to true, so a naive
`onUpdate` poll spins for the whole session. Stop when `GetStatusReason()` returns a fatal
reason:

```lua
if not NCZoningApi.IsReady() then
  local reason = NCZoningApi.GetStatusReason()
  if reason == "cache_missing" or reason == "cache_invalid" or reason == "storage_unavailable" then
    stopPolling()   -- no data is coming this session
  end
end
```

A full worked example is in [`examples/cet_lua_consumer.lua`](../examples/cet_lua_consumer.lua).

## The NCZLocation data model

Each location is a `ref<NCZLocation>` (redscript) / handle (Lua). Fields are read through
accessor methods (redscript `loc.Name()`, Lua `loc:Name()`):

| Accessor | Type | Notes |
| --- | --- | --- |
| `Id()` | String | UUID for manual entries, `nexus-<id>` for auto-discovered; stable |
| `Name()` | String | |
| `NexusId()` | String | numeric, or `WIP` / `Dummy` |
| `Pos()` | Vector4 | raw CET world coordinates, usable in game with no transform |
| `Yaw()` | Float | |
| `Category()` | String | `location-overhaul`, `new-location`, or `other` |
| `District()` | String | never empty (Badlands is the default region) |
| `Subdistrict()` | String | empty when the entry has none |
| `Description()` | String | |
| `Credits()` | String | may be empty |
| `ThumbnailUrl()` / `PictureUrl()` | String | Nexus image URLs; may be empty |
| `RecentlyUpdated()` | Bool | server-computed; true when the mod was updated inside the API's recency window |

Arrays (`Tags()`, `Authors()`, `Archives()`) are also exposed as count/index accessors that are
safe to call inline: `TagCount()` / `TagAt(i)`, `AuthorCount()` / `AuthorAt(i)`, and
`ArchiveCount()` / `ArchiveAt(i)`.

`Archives()` is the `.archive` / `.xl` filenames the mod installs. An empty list means "cannot
say", never "not installed" - see [Installed-mod detection](#installed-mod-detection).

### Player's current district

NCZoningCore ships each location's district and subdistrict, but not district geometry. To
answer "what is in the player's current district", read the player's district from the game's
own `DistrictManager` (`GetCurrentDistrict()`), map it to the API's spaced name (for example the
game's `CityCenter` to the API's `City Center`), and filter with `GetLocationsByDistrict`.

## How the CET Lua bridge works

Background, if you want to know why the Lua patterns look the way they do.

- `NCZoningApi` is reachable from CET Lua because CET reads the game's shared reflection system
  and exposes every registered redscript class to Lua automatically (see
  [References](#references)). A redscript class in a module appears in Lua under its full name
  with dots replaced by underscores; `NCZoningApi` has no module, so it keeps its bare name.
- The data-ready signal is not a message the framework sends to CET. `OnDataReady` is an empty
  redscript method that NCZoningCore calls after each store update. CET's `Observe` installs a
  hook on that method, so your Lua function runs with the arguments. If CET is not installed, or
  nobody is observing, the call is a no-op. This "observe an empty stub method" pattern is the
  same one used by other redscript-plus-CET mods (see [References](#references)).

Traffic only ever runs this way: Lua reads, and nothing writes into the Core from Lua. Installed-mod
detection is not an exception - the scan runs in redscript, and Lua reads its result through
`GetInstallStateInt` like everything else.

## Threading and non-goals

- Consumers do not deal with threads. NCZoningCore parses network responses off the game thread
  and passes the result back onto the game thread before updating the store or firing any
  signal, so every callback, event, and read you see runs on the game thread.
- Non-goals in v1: NCZoningCore does not report telemetry or player position, poll on a loop, or
  authenticate. It is a read-only data provider with no UI, with one exception: when it has no
  registry data and no way to get any, it pushes a single on-screen message telling the user how
  to fix it.

## Availability caveat

NCZoningCore is pure redscript and survives game patches, but its RED4ext plugin dependencies
(Codeware, the Red\* plugins) need per-patch rebuilds by their authors. Right after a game update
the framework can be temporarily unavailable until those catch up. A soft-dependency consumer
keeps working in that window.

## References

- RED4ext: <https://github.com/wopss/RED4ext>
- redscript: <https://github.com/jac3km4/redscript>
- Codeware (CallbackSystem, ScriptableService): repo <https://github.com/psiberx/cp2077-codeware>, wiki <https://github.com/psiberx/cp2077-codeware/wiki>
- RedHttpClient / RedData / RedFileSystem (each states its install requirement as RED4ext, and that it is usable from redscript and CET): <https://github.com/rayshader/cp2077-red-httpclient>, <https://github.com/rayshader/cp2077-red-data>, <https://github.com/rayshader/cp2077-red-filesystem>
- Cyber Engine Tweaks, which exposes redscript types to Lua and provides `Observe`: docs at <https://wiki.redmodding.org/cyber-engine-tweaks>
- Native Interactions Framework, a mod that uses the observe-a-stub-method pattern: <https://github.com/justarandomguyintheinternet/nativeInteractions>
