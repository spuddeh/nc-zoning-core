# NCZoningCore

A pure-redscript Cyberpunk 2077 framework mod. It fetches the NC Zoning
registry (an interactive map of location mods at nczoning.net) from
`https://api.nczoning.net/v1/`, caches it offline-first, and exposes it in
game as a public redscript API that other mods can build on. It has no UI of
its own, makes no writes, and sends no telemetry.

## Status

In development, v0.1.0 (pre-release). The scaffold and data model are in place;
the network fetch and offline cache are being built.

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
- RedHttpClient 0.7.1 or newer
- Cyberpunk 2077 2.31

Note: RED4ext family plugins usually need a rebuild after each game patch, so
this mod can be temporarily unavailable right after an update until its
dependencies catch up. Consumer mods that use a soft dependency degrade
gracefully in that window.

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

## Install

Loose files: unpack `r6\` into your Cyberpunk 2077 game directory. Do not
bundle these scripts into another mod; redscript compiles everything together,
so a second copy is a duplicate-class error that breaks every redscript mod.
Install it once as a standalone dependency, like Codeware.

## License

Licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE). You may
use, modify, and share this mod and its source for any noncommercial purpose,
as long as you credit the original creator. Commercial use, including paid mods
or selling, is not permitted.

## Disclaimer

This mod was developed with the assistance of an LLM. All in-game testing and
code validation was performed by a human. No rogue AIs were permitted through
the Blackwall.
