# Features

## Shipping

- Nothing yet (pre-release).

## Implemented (data model + in-memory queries; not yet wired to a live fetch)

- NCZLocation data model matching the frozen /v1 API contract, including the
  full-entry fields (description, credits, image URLs) and the per-location
  district / subdistrict classification.
- In-memory registry queries: all locations, by id, by category, by tag, by
  district, by subdistrict, and near a world position.
- Public NCZoning.Api surface with a Version (semver) and ApiVersion (breaking
  change handshake) plus ready, stale, and dataset-version status.
- NCZoningDataEvent carrying dataset version, count, and an error reason.

## Planned

- One-per-session conditional GET of /v1/locations?full=1, with the ETag read
  from the response header. (No /v1/districts fetch: the game resolves the
  player's district natively and each location already carries its own.)
- Offline-first RedFileSystem cache with ETag revalidation and a stale flag.
- Dispatch of NCZoning-DataReady, NCZoning-DataRefreshed, and NCZoning-DataError,
  with the worker-thread to game-thread bounce via DelaySystem.
- CET Lua bridge examples and consumer documentation (soft-dep, events, threading).
- v1.0 Nexus release against the /v1 contract.
