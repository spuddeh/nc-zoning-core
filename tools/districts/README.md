# District normalization map (Layer 1)

The game and the NC Zoning API name districts in two different vocabularies:

- The game uses `gamedataDistrict` enum records, reached at runtime through
  `DistrictManager.GetCurrentDistrict()` -> `District.GetDistrictID()` (a `TweakDBID`
  like `t"Districts.Kabuki"`).
- The API uses editorial display strings on `/v1/districts` (`"Watson"` /
  `"Kabuki"`), the same names a player sees on [nczoning.net](https://nczoning.net).

Most names match mechanically once you snake_case them, but a handful differ by
casing, lore, or granularity. This tool builds the **verified** translation table
and generates the shipped reds lookup so a consumer mod can turn the player's live
game district into the API's district/subdistrict strings.

## What it produces

`build-district-map.py` reads two inputs, cross-references them, verifies the
result, and writes two outputs:

| | file | role |
| --- | --- | --- |
| in  | `game-districts.json` | slim, self-contained copy of the 132 `gamedataDistrict` records (`enumName`, TweakDB `path`, `parentDistrict`, `localizedName`). Extracted from the map project's TweakDB dump. |
| in  | `/v1/districts` | fetched live with `curl` (Python's UA gets a 403 from the API WAF), or a local json passed as an argument. |
| out | `district-map.json` | the verified table (source of truth, human-readable). |
| out | `../../r6/scripts/NCZoningCore/NCZoningDistricts.reds` | **GENERATED — do not hand-edit.** The shipped `NCZDistrictMap.Lookup(TweakDBID)` Layer-1 lookup. |
| out | `district-resolution-audit.txt` | reachability report: every one of the 132 game districts and the API name it resolves to (direct or via the simulated parent walk). Review artifact. |

The reds keys on the record's TweakDB **path**, not its enum name: in 105 of 132
records the two differ (enum `Badlands_BiotechnicaFlats` -> path
`Districts.BiotechnicaFlats`), and `District.GetDistrictID()` returns the path.

## Regenerate + verify

```sh
python build-district-map.py                 # fetches /v1/districts via curl
python build-district-map.py some-districts.json   # or use a saved API payload
```

Exit code `0` and `verify errors: NONE` means the map is sound. The script
**fails non-zero** if any of these break, so it doubles as the verification
harness — re-run it whenever the API district list changes:

- a mapped district/subdistrict string is not present in the live API,
- a canonical API district or subdistrict is not covered by any game enum,
- an API entry (other than the known POI-only `SKIP` set) has no game enum,
- an `_EXCLUDED` game enum leaked into the table.

## Editorial decisions (baked into the script, confirmed by the author)

These are the only non-mechanical calls. They live at the top of
`build-district-map.py` so the reasoning ships with the tool:

- **`OVERRIDE`** — API ids the matcher can't resolve mechanically:
  `ncx_morro_rock` -> `MorroRock` (the API renamed "Morro Rock" to "NCX Spaceport /
  Morro Rock"), `socal_border_crossing` -> `Badlands_SoCalBorderCrossing` (casing).
- **`SKIP`** — API POIs with no game district: `north_oaks_casino` (a map POI a
  player's `DistrictManager` never reports).
- **`EXTRA`** — game enums that fold into an API district but have no API entry of
  their own: `NorthBadlands` / `SouthBadlands` (the map never splits the Badlands),
  `MorroRock_NCX`, and `Badlands_Spaceport` (`Districts.NCSpaceport` — the game
  parents the spaceport under Badlands, so it must map directly or a parent-walk
  would wrongly report "Badlands"; found by live testing).
- **`_EXCLUDED`** — game enums that must map to nothing: `Dogtown_Brooklyn` (an NPC
  memory-flashback location in Brooklyn, a different city; never legitimately
  reported in Night City, so `Lookup` returns `null`).

## Layers

This tool builds **Layer 1** only: the static game-district -> API-string table.
A consumer walks **Layer 2** at runtime — read `DistrictManager.GetCurrentDistrict()`,
call `NCZDistrictMap.Lookup(district.GetDistrictID())`, and if it returns `null`
walk up the parent chain and retry. Layer 2 lives in the demo/consumer, not here.

## Verifying in-game

`console-commands.md` has the CET console one-liners for checking the map live:
current district -> API name, a batch table smoke test, LocKey display-name lookup,
and a self-discovery probe. Those commands also document the confirmed live access
path (the `districtManager` field, `GetCurrentDistrict`/`GetDistrictID`, and the
`NCZoning_Api_NCZDistrictMap` Lua global).
