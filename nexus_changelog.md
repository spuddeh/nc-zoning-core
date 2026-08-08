# NC Zoning Board - Core - Release Changelog

Public, user-facing changelog. Plain language, only what matters to the people installing this mod
and to the mod authors building on it. The full technical detail lives in `@changelog.md`.

### v1.1.0

- Changed: Cyber Engine Tweaks is no longer needed. Installed-mod detection now runs through
  RedFunctions, which is required from this version on. If you installed CET only for this mod,
  you no longer need it.
- Fix: "Recently updated" is worked out on your machine against the real date, instead of being
  decided when the registry was published. Playing offline, or on a cached copy of the registry,
  no longer leaves mods flagged as recently updated weeks after they stopped being.
- Fix: A location mod that ships only ArchiveXL files now reads as "unknown" rather than
  "not installed". Those files cannot be detected by anything, so calling them missing told you
  to download a mod you may already have.
- Fix: Location mods added to the registry while the game is starting are checked too, instead of
  being reported as missing without ever having been looked for.
- New: Consumer mods can read a location's update date and the recency window, so they can show
  "updated 3 days ago" rather than only a recent-or-not flag.
- New: District and subdistrict names can be shown in your game's language. The registry publishes
  them in English, so Core now asks Cyberpunk for its own name for the area - which means all
  twelve of the game's languages, and the same wording you see on the world map.
- Fix: Locations no longer show as installed because a different mod shipped the same file. Some
  authors bundle a shared prop pack into their download, so installing one location could mark five
  others you had never downloaded. Files that more than one mod ships are now ignored, and only
  files unique to a mod count.
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
Cyber Engine Tweaks is no longer required - detection uses RedFunctions. District names show in your game's language. A location no longer reads as installed because another mod shipped the same file. Adds log levels, an RCF card and 19 translations.

<!-- nexus-description-end -->

Changed: Cyber Engine Tweaks is no longer needed. Installed-mod detection now runs through RedFunctions, which is required from this version on. If you installed CET only for this mod, you no longer need it.
Fix: "Recently updated" is worked out on your machine against the real date, instead of being decided when the registry was published. Playing offline, or on a cached copy of the registry, no longer leaves mods flagged as recently updated weeks after they stopped being.
Fix: A location mod that ships only ArchiveXL files now reads as "unknown" rather than "not installed". Those files cannot be detected by anything, so calling them missing told you to download a mod you may already have.
Fix: Location mods added to the registry while the game is starting are checked too, instead of being reported as missing without ever having been looked for.
New: Consumer mods can read a location's update date and the recency window, so they can show "updated 3 days ago" rather than only a recent-or-not flag.
New: District and subdistrict names are shown in your game's language. The registry publishes them in English, so the Core now asks Cyberpunk for its own name for each area - all twelve of the game's languages, and the same wording you see on the world map.
Fix: A location no longer shows as installed because a different mod shipped the same file. Some authors bundle a shared prop pack into their download, so installing one location could mark five others you had never downloaded. A file that more than one mod ships is now ignored, and only files unique to a mod count.
New: A mod card for the Redscript Configuration Framework 2.1.0, so the Core appears in its new picker with a header image, category and description.
New: Translation slots for all 19 game languages. A translation is a single file, and anyone can release one as its own mod without waiting for an update here.
Changed: Log lines now carry a level, so RCF 2.1.0's log viewer shows errors in red and warnings in amber, and can filter to one level.
Changed: RedLogger 1.3.0 or newer is now required. RCF 2.1.0 calls RedLogger functions older builds do not have, and the two together stop every redscript mod on your machine from loading. Mods built on the Core inherit this requirement.
```

> File description: 250 / 255 characters.

---

## Stickied Comment BBCode

```text
[color=#00f0ff][size=5][b]- Changes -[/b][/size][/color]

[b][size=3]Version 1.1.0[/size][/b]
[list][*]Changed: Cyber Engine Tweaks is no longer needed. Detection uses RedFunctions, now required.
[*]Fix: "Recently updated" is worked out on your machine, so an offline copy stops flagging mods forever.
[*]Fix: A mod shipping only ArchiveXL files reads as "unknown" rather than "not installed".
[*]Fix: Locations added to the registry while the game starts are checked too.
[*]New: Consumer mods can read a location's update date and the recency window.
[*]New: District and subdistrict names show in your game's language, matching the world map.
[*]Fix: A location no longer reads as installed because another mod shipped the same file.
[*]New: A mod card for the Redscript Configuration Framework 2.1.0.
[*]New: Translation slots for all 19 game languages, releasable as separate mods.
[*]Changed: Log lines now carry a level, colour-coded in RCF 2.1.0's log viewer.
[*]Changed: RedLogger 1.3.0 or newer is now required.
[/list]
[b][size=3]Version 1.0.0[/size][/b]
[spoiler][list][*]Initial public release.
[/list][/spoiler]
```

> Character count: 1125 / 5000
