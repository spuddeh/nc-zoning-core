# NC Zoning Board - Core - Release Changelog

Public, user-facing changelog. Plain language, only what matters to the people installing this mod
and to the mod authors building on it. The full technical detail lives in `@changelog.md`.

### v1.0.0

- New: Initial public release. NC Zoning Board - Core fetches the NC Zoning Board location
  registry once per launch, caches it offline-first, and exposes it to other mods from both
  redscript and CET Lua. It has no UI and no settings of its own; it exists for other mods
  to build on.
- New: Works offline after the first online launch, and only re-downloads when the registry
  has actually changed.
- New: RedHttpClient is optional. Without it the mod has no networking component at all and
  reads a `locations.json` you download by hand - the mod page carries the command. If there
  is no data and no way to fetch any, the mod says so on screen instead of failing silently.
- New: Installed-mod detection. A consumer mod can ask which location mods you already have,
  so it can mark what is present and what is missing. Needs Cyber Engine Tweaks; without it,
  every location reads as "unknown".
- New: Writes its own log at `r6\logs\mods\NCZoningCore__<date_time>.log` through RedLogger
  (a required dependency), keeping the five most recent sessions.

---

## Stickied Comment BBCode

```
[color=#00f0ff][size=5][b]- Changes -[/b][/size][/color]

[b][size=3]Version 1.0.0[/size][/b]
[list][*]Initial public release.
[/list]
```

> Character count: 137 / 5000
