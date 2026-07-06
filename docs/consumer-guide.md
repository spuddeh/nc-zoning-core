# NCZoningCore Consumer Guide

How to build a mod on top of NCZoningCore, from either redscript or CET Lua.

NCZoningCore is a pure-redscript framework. It fetches the NC Zoning registry (an interactive
map of location mods at nczoning.net) once per game session, caches it offline-first, and
exposes it in game as a read-only API. Your mod reads that registry: each entry's name,
authors, world coordinates, category, tags, and district/subdistrict.

Every code fact below is drawn from the shipped source in this repository. External behaviour
(dependencies, the CET Lua bridge) is cited to its upstream source in [References](#references).

## Requirements

NCZoningCore itself needs, at runtime:

- RED4ext 1.29.0+, redscript 0.5.31+, and Cyberpunk 2077 2.31
- Codeware, RedData 0.9+, RedFileSystem 0.15+, RedHttpClient 0.7.1+

These are RED4ext plugins usable from redscript; per each plugin's own install requirements,
the mandatory base is RED4ext, and RedData underpins the JSON features (see
[References](#references)). NCZoningCore's redscript calls no CET (Cyber Engine Tweaks) API, so
**the framework does not require CET**. CET is required only by a consumer that is itself a CET
Lua mod (see [Consuming from CET Lua](#consuming-from-cet-lua)).

NCZoningCore ships redscript only. There are no Lua files in the distribution; the files in
`examples/` are documentation, not loaded by the framework.

## When is data available

One fetch runs per game launch. On session start NCZoningCore loads its offline cache
immediately (so the registry is usable within a second or two of entering the world, even with
no network), then revalidates over the network. Your consumer should therefore wait for a
"data ready" signal rather than assume the data is present at startup. Both consumer types have
a signal and a simple readiness check, described below.

Status you can query at any time:

- `IsReady()` - the store is populated and queryable.
- `IsStale()` - the store was served from cache and has not yet been confirmed against the
  server this session (cleared once a network response confirms it).
- `GetDataVersion()` - the dataset content hash (changes when the registry changes).

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

### Events

NCZoningCore dispatches three events through Codeware's CallbackSystem. Register with the frozen
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
- `NCZoning-DataError` - a fetch failed after retries. `event.Reason()` holds a code;
  `IsReady()` may still be true if the offline cache is serving.

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

A full worked example is in [`examples/RedscriptConsumer.reds`](../examples/RedscriptConsumer.reds).

> Gotcha: never apply `ArraySize` / `ArrayContains` / index directly to one of these array
> returns inline; bind the result to a `let` local first. Applying an array intrinsic to a
> method's array return value reads garbage in redscript (an rvalue-temporary issue). This is a
> redscript-wide gotcha, not specific to NCZoningCore.

## Consuming from CET Lua

CET Lua reaches NCZoningCore through a dedicated facade class, `NCZoningApi`. You do not import
anything and NCZoningCore ships no Lua; `NCZoningApi` is simply a global in CET Lua because CET
exposes every redscript class through the shared reflection system (see
[How the CET Lua bridge works](#how-the-cet-lua-bridge-works) and [References](#references)).

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

The Lua facade exposes the same reads as the redscript API, plus `GetLocationCount()`. It is
read-only by design, so a Lua consumer cannot reach the framework's internal mutating methods.

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

Note: the CallbackSystem events in the redscript section are the redscript consumer path. For
CET Lua, use the `Observe` hook above (or `IsReady()` polling). In this framework's own in-game
testing, custom CallbackSystem events dispatched from redscript were not delivered to CET Lua
listeners, which is why the `OnDataReady` hook is provided as the Lua path.

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
| `Source()` | String | `manual` or `auto` |
| `Description()` | String | |
| `Credits()` | String | may be empty |
| `ThumbnailUrl()` / `PictureUrl()` | String | Nexus image URLs; may be empty |

Arrays (`Tags()`, `Authors()`) are also exposed as count/index accessors that are safe to call
inline: `TagCount()` / `TagAt(i)` and `AuthorCount()` / `AuthorAt(i)`.

### Player's current district

NCZoningCore ships each location's district and subdistrict, but not district geometry. To
answer "what is in the player's current district", read the player's district from the game's
own `DistrictManager` (`GetCurrentDistrict()`), map it to the API's spaced name (for example the
game's `CityCenter` to the API's `City Center`), and filter with `GetLocationsByDistrict`.

## How the CET Lua bridge works

Useful background if you want to understand why the Lua patterns look the way they do.

- NCZoningCore ships no Lua and calls no CET function. `NCZoningApi` is reachable from CET Lua
  only because CET reads the game's shared reflection system and exposes every registered
  redscript class to Lua automatically (see [References](#references)). A redscript class in a
  module appears in Lua under its full name with dots replaced by underscores; `NCZoningApi` has
  no module, so it keeps its bare name.
- The data-ready signal is not a message the framework "sends" to CET. `OnDataReady` is an empty
  redscript method; NCZoningCore simply calls it after each store update. CET's `Observe`
  installs a hook on that method, so when NCZoningCore calls it, your Lua function runs with the
  arguments. If CET is not installed, or nobody is observing, the call is a harmless no-op and
  the framework is unaffected. This "observe an empty stub method" pattern is the same one used
  by other redscript-plus-CET mods (see [References](#references)).

So NCZoningCore stays a self-contained redscript data provider; a CET Lua consumer reaches in
through reflection and hooking, rather than the framework reaching out.

## Threading and non-goals

- Consumers do not deal with threads. NCZoningCore parses network responses off the game thread
  and marshals the result back onto the game thread before updating the store or firing any
  signal, so every callback, event, and read you see runs on the game thread.
- Non-goals in v1: NCZoningCore does not write anything, report telemetry or player position,
  show any UI of its own, poll on a loop, or authenticate. It is a read-only data provider.

## Availability caveat

NCZoningCore is pure redscript and survives game patches, but its RED4ext plugin dependencies
(Codeware, the Red* plugins) need per-patch rebuilds by their authors. Right after a game update
the framework can be temporarily unavailable until those catch up. A soft-dependency consumer
degrades gracefully in that window.

## References

- RED4ext: <https://github.com/wopss/RED4ext>
- redscript: <https://github.com/jac3km4/redscript>
- Codeware (CallbackSystem, ScriptableService): repo <https://github.com/psiberx/cp2077-codeware>, wiki <https://github.com/psiberx/cp2077-codeware/wiki>
- RedHttpClient / RedData / RedFileSystem (each states its install requirement as RED4ext, and that it is usable from redscript and CET): <https://github.com/rayshader/cp2077-red-httpclient>, <https://github.com/rayshader/cp2077-red-data>, <https://github.com/rayshader/cp2077-red-filesystem>
- Cyber Engine Tweaks, which exposes redscript types to Lua and provides `Observe`: docs at <https://wiki.redmodding.org/cyber-engine-tweaks>
- Native Interactions Framework, a real mod that uses the observe-a-stub-method pattern: <https://github.com/justarandomguyintheinternet/nativeInteractions>
