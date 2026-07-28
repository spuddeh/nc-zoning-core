# NCZoningCore

A pure-redscript Cyberpunk 2077 framework mod. It fetches the NC Zoning
registry (an interactive map of location mods at nczoning.net) from
`https://api.nczoning.net/v1/`, caches it offline-first, and exposes it in
game as a public redscript API that other mods can build on. It has no UI of
its own, makes no writes, and sends no telemetry.

## The NC Zoning project

NCZoningCore is the in-game half of [NC Zoning](https://nczoning.net), the
interactive map of Cyberpunk 2077 location mods.

- Explore the map: <https://nczoning.net>
- Join the community: [Locations Hub Discord](https://discord.gg/sc4yEx2fNf)
- Showcase: <https://www.youtube.com/watch?v=30Daism2E-c>
- Trailer: <https://www.youtube.com/watch?v=LJVJ2lN4aQ0>

## Status

Feature complete and verified in game, v0.2.0 (pre-release): fetch, offline cache
with ETag revalidation, the public API and events, and the CET Lua bridge are all
implemented and tested. RedHttpClient is a soft dependency as of 0.2.0, verified by
compiling both with and without it. Preparing the first public release.

## What consumers get

Import `NCZoning.Api` and read a ready-made registry of location mods: their
names, authors, world coordinates, category, tags, and district or subdistrict
classification. Events (`NCZoning-DataReady`, `NCZoning-DataRefreshed`,
`NCZoning-DataError`) fire through Codeware's CallbackSystem, so both redscript
and CET Lua mods can react.

## Requirements

- RED4ext 1.29 or newer
- redscript 0.5.31 or newer
- Codeware
- RedData 0.9 or newer
- RedFileSystem 0.15 or newer
- [RedLogger](https://www.nexusmods.com/cyberpunk2077/mods/31920) 1.1.0 or newer
- Cyberpunk 2077 2.31

RedLogger is required rather than optional, and that is a deliberate cost. It is
what NCZoningCore logs through, and because it is a framework the usual failure
report is "the registry never loaded" — which is answerable only from a log. Its
lines land in `r6\logs\mods\NCZoningCore__<date_time>.log`, one file per session
with the five most recent kept, so a bug report is one small file scoped to this
mod alone rather than a shared log or a special debug build.

Optional:

- RedHttpClient 0.7.1 or newer
- **Cyber Engine Tweaks** — only for installed-mod detection (see below)

## Installed-mod detection needs CET, and only for that

The registry publishes the `.archive` / `.xl` filenames each location mod installs, so
NCZoningCore can tell a consumer which mods are actually present. Doing that means
reading `archive/pc/mod/`, and **nothing reachable from redscript can look there**:
RedFileSystem confines every mod to `r6/storages/<name>/`, and the engine exposes no
archive surface to script at all. CET's Lua `ModArchiveExists` is the only route.

So NCZoningCore ships one small CET Lua component that does the scan and hands the
result back to redscript. **Consumers stay pure redscript and never touch Lua.**

Without CET the component never runs and every location reports `Unknown` — which is
distinct from "not installed" and must be rendered as such. Check
`IsInstallDetectionAvailable()` before offering the player any installed/missing filter.

`Unknown` is also permanent for **AMM location mods**: their files live in CET's own
sandboxed folder, which no mod can read, so they can never be detected.

Note: RED4ext family plugins usually need a rebuild after each game patch, so
this mod can be temporarily unavailable right after an update until its
dependencies catch up. Consumer mods that use a soft dependency degrade
gracefully in that window.

## RedHttpClient is optional

RedHttpClient is the plugin that lets the game make HTTPS requests, and it is the
only reason NCZoningCore touches the network at all. Some people would rather not
install a general-purpose HTTP plugin, which is a fair position, so it is a **soft
dependency**: the mod compiles and runs without it.

The trade-off is simple.

- **With RedHttpClient.** NCZoningCore downloads the registry once per session,
  caches it, and revalidates with an ETag on later launches. Nothing for you to do.
- **Without RedHttpClient.** NCZoningCore never opens a socket. It reads the
  registry from a file you supply yourself (see below), and serves it as
  permanently stale data. It cannot refresh, so you re-download when you want
  newer data.

If RedHttpClient is absent *and* you have not supplied the file, the mod has no
data at all. It says so on screen a few seconds into the session, and reports
`cache_missing` to any consumer mod, rather than quietly behaving like an empty
registry.

Technically this works because every reference to RedHttpClient in the source, the
`import` included, is behind `@if(ModuleExists("RedHttpClient"))`. redscript
evaluates those conditions before name resolution, so with the plugin absent that
code is not compiled and cannot fail to compile.

### Getting the data by hand

Run this from your Cyberpunk 2077 root directory. `--create-dirs` makes the
storage folder for you.

```powershell
curl.exe -L "https://api.nczoning.net/v1/locations?full=1" --create-dirs -o "r6\storages\NCZoningCore\locations_full.json"
```

The finished path is `Cyberpunk 2077\r6\storages\NCZoningCore\locations_full.json`.
That folder is fixed: RedFileSystem sandboxes every mod to `r6\storages\<mod name>\`
and NCZoningCore cannot read from anywhere else.

The path is relative, so check it landed where you meant. It is easy to download a
perfectly good file into the wrong folder and see no error at all:

```powershell
dir r6\storages\NCZoningCore
```

You should see `locations_full.json`, around 210 KB.

There is no second file to fetch. `meta.json` holds the ETag used for revalidation,
which only matters when RedHttpClient is doing the fetching, so an offline install
does not need it.

**Vortex, or a manual install**: nothing special to do. Vortex deploys into the real
game folder, so the command above is all you need.

**Mod Organizer 2**: the game directory is virtualised, so pick one of these instead:

- run the command from `overwrite\`, so the file lands in
  `overwrite\r6\storages\NCZoningCore\`; or
- create `r6\storages\NCZoningCore\locations_full.json` inside a mod folder and let
  MO2 deploy it, which keeps it out of overwrite and lets you uninstall it cleanly.

The first is the same place the mod would have written to anyway: when RedHttpClient
*is* installed, the game's write goes through the virtual filesystem and MO2 lands it
in `overwrite\r6\storages\NCZoningCore\`. So if you later install RedHttpClient, it
will refresh the file you put there rather than create a second one somewhere else.

To confirm it worked, the on-screen error stops appearing. If you have CET, its
console can confirm it directly (wrap the calls in `print` - the console does not
echo return values on its own):

```lua
print(NCZoningApi.GetLocationCount())   --> 295, or whatever the registry holds
print(NCZoningApi.GetStatusReason())    --> offline_snapshot
print(NCZoningApi.IsHttpAvailable())    --> false
```

## For mod authors

Build on NCZoningCore from redscript or CET Lua. See the
[Consumer Guide](docs/consumer-guide.md) for the full API, both consumption
patterns, and worked examples in [`examples/`](examples/).

In short: redscript consumers `import NCZoning.Api.*` (or guard with
`@if(ModuleExists("NCZoning.Api"))` for a soft dependency) and subscribe to the
`NCZoning-DataReady` / `-DataRefreshed` / `-DataError` CallbackSystem events. CET
Lua consumers call the `NCZoningApi` facade (`NCZoningApi.GetAllLocations()` etc.)
and `Observe('NCZoningApi', 'OnDataReady', ...)` for the data-ready signal. Gate
on `ApiVersion()`, which increments only on a breaking change.

Because RedHttpClient is optional, a consumer can land in a session where the
registry is empty and will stay empty. `IsHttpAvailable()` and `GetStatusReason()`
tell you which situation you are in, so you can show a useful message instead of an
empty list. `GetStatusReason()` returns `""` for live data, or `offline_snapshot`,
`cache_missing`, `cache_invalid`, `storage_unavailable`, or `fetch_failed`. Read it
alongside `IsReady()`: a reason with `IsReady() == true` is informational (the data
works, it just cannot refresh), and with `IsReady() == false` it is fatal.

## Install

Loose files: unpack `r6\` into your Cyberpunk 2077 game directory. Do not
bundle these scripts into another mod; redscript compiles everything together,
so a second copy is a duplicate-class error that breaks every redscript mod.
Install it once as a standalone dependency, like Codeware.

## Credits

- [Kaoziun](https://www.nexusmods.com/profile/Kaoziun) for the original NC Zoning
  vision and community leadership.
- [Akiway](https://www.nexusmods.com/profile/Akiway) for improvements to the NC Zoning
  map UI and UX.
- [manavortex](https://www.nexusmods.com/profile/manavortex) for the initial data
  structure and guidance.
- [psiberx](https://www.nexusmods.com/profile/psiberx/mods) for Codeware.
- [rayshader](https://www.nexusmods.com/profile/RayshaderFR) for RedHttpClient,
  RedData, and RedFileSystem.
- The location-mod authors the registry maps, and the Locations Hub community.

## License

Licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE). You may
use, modify, and share this mod and its source for any noncommercial purpose,
as long as you credit the original creator. Commercial use, including paid mods
or selling, is not permitted.

## Disclaimer

This mod was developed with the assistance of an LLM. All in-game testing and
code validation was performed by a human. No rogue AIs were permitted through
the Blackwall.
