# NCZoningCore - Release Changelog

Public, user-facing changelog. Plain language, only what matters to the people installing this mod
and to the mod authors building on it. The full technical detail lives in `@changelog.md`.

### [Unreleased - v0.2.0]

- New: RedHttpClient is now **optional**. NCZoningCore installs and runs without it. If you would
  rather not install a general-purpose HTTP plugin, you no longer have to: with RedHttpClient absent
  the mod has no networking component at all, rather than one it simply chooses not to use.
- New: Without RedHttpClient, you supply the location registry yourself by downloading a single
  `locations_full.json` into `r6\storages\NCZoningCore\`. The README and the mod description carry
  the command. That data is then served as a permanent offline snapshot.
- New: The mod now tells you on screen when it has no location data and no way to fetch any, instead
  of failing silently. Without it, every mod built on NCZoningCore would just look broken for a
  reason you could not discover.
- New: Mods built on NCZoningCore can now tell the difference between "the data is usable but cannot
  refresh" and "no data is coming this session", so they can show you something useful instead of an
  empty list. Added `GetStatusReason()` and `IsHttpAvailable()` to both the redscript API and the CET
  Lua facade, plus an `OnDataError` hook for Lua consumers.
- New: The consumer guide documents the no-network path and the reason codes.

### [Unreleased - v0.1.0]

- New: First build of NCZoningCore, a framework mod (a modder's resource) that fetches the NC Zoning
  location registry once per launch, caches it offline, and exposes it to other mods from both
  redscript and CET Lua. It has no UI and no settings of its own; it exists for other mods to build on.
- New: Offline-first cache. The registry is saved locally, so it loads instantly on the next launch
  and only re-downloads when it has actually changed.
- New: Public API and lifecycle events for mod authors, plus worked examples for redscript and CET Lua
  consumers and a full consumer guide.

---

## Notes

Not yet published on Nexus. Both sections stay marked `[Unreleased]` until the page goes live; at that
point the shipped version is renamed to `vX.Y.Z` and a fresh `[Unreleased]` section opens above it.

Versioning: this mod stays in `0.x` while unpublished. **`1.0.0` lands when it goes live on Nexus.**

A stickied-comment BBCode block is not generated yet: there is no Nexus page to post it to. Generate
it with `track-changes` at release time, from the entries above.
