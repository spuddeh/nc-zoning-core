# NC Zoning Board - Core - Release Changelog

Public, user-facing changelog. Plain language, only what matters to the people installing this mod
and to the mod authors building on it. The full technical detail lives in `@changelog.md`.

### [Unreleased - v1.1.0]

- New: A mod card for the Redscript Configuration Framework 2.1.0. The Core now appears in RCF's
  new picker with its header image, category and a short description.
- New: Translation slots for all 19 game languages. A translation is a single file, and anyone can
  release one as its own mod without waiting for an update here.
- Changed: Log lines now carry a level, so RCF 2.1.0's log viewer shows errors in red and warnings
  in amber, and can filter to one level.
- Changed: RedLogger 1.3.0 or newer is now required. RCF 2.1.0 calls RedLogger functions older
  builds do not have, and the two together stop every redscript mod on your machine from loading.
  Mods built on the Core inherit this requirement.

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

## Release body

Paste into the GitHub release body. The workflow splits on `<!-- nexus-description-end -->`: what is
above it becomes the Nexus **file description**, what is below becomes the **changelog entry**.

**Nexus stores a changelog as one bullet PER LINE.** The lines below are therefore unwrapped, and
carry no `-`, no markdown and no version heading: a wrapped line arrives as two bullets, a leading
dash arrives inside the bullet, and the version is sent in its own field.

```text
Adds log levels, a mod card for the Redscript Configuration Framework 2.1.0, and translation slots for 19 languages. RedLogger 1.3.0 or newer is now required.

<!-- nexus-description-end -->

New: A mod card for the Redscript Configuration Framework 2.1.0, so the Core appears in its new picker with a header image, category and description.
New: Translation slots for all 19 game languages. A translation is a single file, and anyone can release one as its own mod without waiting for an update here.
Changed: Log lines now carry a level, so RCF 2.1.0's log viewer shows errors in red and warnings in amber, and can filter to one level.
Changed: RedLogger 1.3.0 or newer is now required. RCF 2.1.0 calls RedLogger functions older builds do not have, and the two together stop every redscript mod on your machine from loading. Mods built on the Core inherit this requirement.
```

> File description: 158 / 255 characters.

---

## Stickied Comment BBCode

```text
[color=#00f0ff][size=5][b]- Changes -[/b][/size][/color]

[b][size=3]Version 1.1.0[/size][/b]
[list][*]New: A mod card for the Redscript Configuration Framework 2.1.0.
[*]New: Translation slots for all 19 game languages, releasable as separate mods.
[*]Changed: Log lines now carry a level, colour-coded in RCF 2.1.0's log viewer.
[*]Changed: RedLogger 1.3.0 or newer is now required.
[/list]
[b][size=3]Version 1.0.0[/size][/b]
[spoiler][list][*]Initial public release.
[/list][/spoiler]
```

> Character count: 488 / 5000
