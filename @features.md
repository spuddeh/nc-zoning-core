# Features

## Shipping

- Nothing yet (pre-release).

## Implemented (data model + in-memory queries; not yet wired to a live fetch)

- NCZLocation and NCZDistrict data model matching the frozen /v1 API contract,
  including the full-entry fields (description, credits, image URLs).
- In-memory registry queries: all locations, by id, by category, by tag, near a
  world position, plus all districts and district by id.
- Public NCZoning.Api surface with a Version (semver) and ApiVersion (breaking
  change handshake) plus ready, stale, and dataset-version status.
- NCZoningDataEvent carrying dataset version, count, and an error reason.

## Planned

- One-per-session conditional GET of /v1/locations?full=1 and /v1/districts,
  with the ETag read from the response header.
- Offline-first RedFileSystem cache with ETag revalidation and a stale flag.
- Dispatch of NCZoning-DataReady, NCZoning-DataRefreshed, and NCZoning-DataError,
  with the worker-thread to game-thread bounce via DelaySystem.
- CET Lua bridge examples and consumer documentation (soft-dep, events, threading).
- v1.0 Nexus release against the /v1 contract.
