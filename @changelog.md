# Changelog

## 0.1.0 (pre-release)

- Initial scaffold of the NCZoningCore framework mod (flat pure-redscript layout,
  no source/packed split, no WolvenKit project).
- Added the NCZoning.Data DTOs (NCZLocation, NCZDistrict, NCZCentroid, and the
  response envelopes) matching the frozen /v1 API contract.
- Added the NCZoningDataEvent payload for the three data lifecycle events.
- Added the internal NCZoning.Core service with the in-memory store plus location
  and district query methods.
- Added the public NCZoning.Api surface (Version and ApiVersion handshake, ready
  and stale status, dataset version, and query forwarders).
- Network fetch, ETag revalidation, and the offline cache are not yet implemented.
