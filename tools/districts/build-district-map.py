#!/usr/bin/env python3
"""
build-district-map.py - generate AND verify the NCZoningCore district normalization map.

Cross-references the game's gamedataDistrict records (game-districts.json, extracted from the
map project's TweakDB dump) against the live NC Zoning API (/v1/districts) and produces:
  - district-map.json                          the verified table (source of truth)
  - ../../r6/scripts/NCZoningCore/NCZoningDistricts.reds   the shipped reds Layer-1 lookup

The reds file carries TWO things:
  1. Lookup(TweakDBID)  - game district -> API district/subdistrict (the Layer-1 map).
  2. AllDistricts() / SubdistrictsOf(district) - the API's district vocabulary, enumerable, so a
     consumer can build a district picker without deriving it from the locations (which omits any
     area that has zero locations). Static: no network, no registry data, valid before the fetch.

It VERIFIES that every mapped district/subdistrict string exists in the API and that every
canonical API district/subdistrict is covered by at least one game enum, and exits non-zero
on any failure. Re-run it whenever the API district list changes.

The enumeration emits ALL subdistricts, canonical or not: "North Oaks Casino" is non-canonical but
has locations attributed to it, and omitting it would strand them in Westbrook's total with no
subdistrict row to reach them from.

Usage:  python build-district-map.py            (fetches /v1/districts with curl)
        python build-district-map.py api.json    (use a local /v1/districts json instead)

The map is game -> API only where they DIFFER editorially; the vast majority is a mechanical
name match. The handful of editorial decisions below were confirmed by the mod author.
"""
import json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.normpath(os.path.join(HERE, "..", "..", "r6", "scripts", "NCZoningCore"))
REDS = os.path.join(SCRIPTS, "NCZoningDistricts.reds")
API_REDS = os.path.join(SCRIPTS, "Api.reds")


def read_version():
    """The mod version, read from Api.reds's Version(). Never hardcode it here: release-check
    requires every 'Mod Version:' header to agree, so a hardcoded constant here rewrites the
    generated file's header back to a stale version on the next regen."""
    src = open(API_REDS, encoding="utf-8").read()
    m = re.search(r'func\s+Version\(\)\s*->\s*String\s*\{\s*return\s*"([0-9]+\.[0-9]+\.[0-9]+)"', src)
    if not m:
        print("FAILED: cannot read Version() from Api.reds", file=sys.stderr)
        sys.exit(1)
    return m.group(1)

# --- confirmed editorial decisions (game enum <-> API), see the wiki decision ------------
# API entries whose game enum the mechanical matcher can't find, resolved by hand:
OVERRIDE = {
    "ncx_morro_rock": "MorroRock",                 # API renamed "Morro Rock" -> "NCX Spaceport / Morro Rock"
    "socal_border_crossing": "Badlands_SoCalBorderCrossing",  # casing: SoCal vs socal
}
# API-only POIs with no game district (a player's DistrictManager never reports these):
SKIP = {"north_oaks_casino"}
# game enums that fold into an API district but have no API entry of their own:
EXTRA = [
    ("NorthBadlands", "Badlands", ""),      # map never splits north/south badlands
    ("SouthBadlands", "Badlands", ""),
    ("MorroRock_NCX", "NCX Spaceport / Morro Rock", ""),
    # The game has THREE spaceport districts, split across two unrelated parents, that the API
    # models as one district "NCX Spaceport / Morro Rock" (game display names confirmed live via
    # their LocKeys, 2026-07-07):
    #   Districts.MorroRock  (top-level)      = "Morro Rock"
    #     -> Districts.NCX   (child)          = "Night City International and Translunar" (airport)
    #   Districts.Badlands (top-level)
    #     -> Districts.NCSpaceport (child)    = "NCX Spaceport"   <- where the player actually stands
    # NCSpaceport's game parent is Badlands, so it MUST map directly here or a parent-walk would
    # wrongly report "Badlands". Live round-trip confirmed: NCSpaceport -> "NCX Spaceport / Morro Rock".
    ("Badlands_Spaceport", "NCX Spaceport / Morro Rock", ""),
]
# game enums that must NOT map to any API district (documented so a future regen keeps them out):
# - Dogtown_Brooklyn: an NPC memory-flashback location in Brooklyn, a different city; a player's
#   DistrictManager never legitimately reports it in Night City, so Lookup should return null.
_EXCLUDED = {"Dogtown_Brooklyn"}
# Reachability allowlist: game districts that legitimately resolve to NO api district even after
# walking the parent chain to the root. Any OTHER nil is a real gap and hard-fails the build.
# - Districts.Brooklyn: the excluded flashback (top-level, no parent).
# - Districts.q307LangleyClinic: a quest-mission interior, not a public explorable district.
KNOWN_UNMAPPED = {"Districts.Brooklyn", "Districts.q307LangleyClinic"}


def to_snake(s):
    s = re.sub(r"(.)([A-Z][a-z]+)", r"\1_\2", s)
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", s)
    return s.lower()


def load_api(argv):
    if len(argv) > 1:
        return json.load(open(argv[1], encoding="utf-8"))["data"]
    out = subprocess.run(["curl", "-s", "https://api.nczoning.net/v1/districts"],
                         capture_output=True, text=True, encoding="utf-8")
    return json.loads(out.stdout)["data"]


def main():
    game = json.load(open(os.path.join(HERE, "game-districts.json"), encoding="utf-8"))["districts"]
    enums = {g["enumName"]: g["path"] for g in game}
    snake = {en: to_snake(en) for en in enums}

    def find(api_id, api_name):
        for en, sn in snake.items():
            if sn == api_id:
                return en
        for en, sn in snake.items():
            if sn.endswith("_" + api_id):     # parent-prefixed game enums (e.g. Badlands_LagunaBend)
                return en
        g = re.sub(r"[ /\-]", "", api_name).lower()
        for en in enums:
            if en.lower() == g:
                return en
        for cand in (api_id + "s", api_id.rstrip("s")):   # singular/plural
            for en, sn in snake.items():
                if sn == cand or sn.endswith("_" + cand):
                    return en
        return None

    api = load_api(sys.argv)
    entries, unmapped = [], []
    for d in api:
        if d["id"] not in SKIP:
            en = OVERRIDE.get(d["id"]) or find(d["id"], d["name"])
            (entries if en else unmapped).append(
                {"gameEnum": en, "gamePath": enums.get(en), "district": d["name"], "subdistrict": ""}
                if en else ("top", d["id"], d["name"]))
        for s in d.get("subdistricts", []):
            if s["id"] in SKIP:
                continue
            en = OVERRIDE.get(s["id"]) or find(s["id"], s["name"])
            (entries if en else unmapped).append(
                {"gameEnum": en, "gamePath": enums.get(en), "district": d["name"], "subdistrict": s["name"]}
                if en else ("sub", s["id"], s["name"]))
    for en, dist, sub in EXTRA:
        if en in enums:
            entries.append({"gameEnum": en, "gamePath": enums[en], "district": dist, "subdistrict": sub})

    # ---- VERIFY ----
    valid_d = {d["name"] for d in api}
    valid_s = {s["name"] for d in api for s in d.get("subdistricts", [])}
    errs = []
    for e in entries:
        if e["gameEnum"] in _EXCLUDED:
            errs.append(f"excluded game enum {e['gameEnum']} must not be mapped")
        if e["gameEnum"] not in enums:
            errs.append(f"unknown game enum {e['gameEnum']}")
        if e["district"] not in valid_d:
            errs.append(f"{e['gameEnum']}: district '{e['district']}' not in API")
        if e["subdistrict"] and e["subdistrict"] not in valid_s:
            errs.append(f"{e['gameEnum']}: subdistrict '{e['subdistrict']}' not in API")
    covered_d = {e["district"] for e in entries}
    covered_s = {e["subdistrict"] for e in entries if e["subdistrict"]}
    miss_d = [d["name"] for d in api if d["name"] not in covered_d]
    miss_s = [s["name"] for d in api for s in d.get("subdistricts", [])
              if s.get("canonical", True) and s["name"] not in covered_s]
    unexpected = [u for u in unmapped]   # any API entry (except SKIP) with no game enum

    # ---- REACHABILITY AUDIT ----
    # The checks above prove the map covers the API. This proves it covers the GAME: simulate the
    # Layer-2 resolver (direct Lookup, else walk parentDistrict to root) for every game district and
    # confirm each reachable one lands on an API district. Catches the spaceport-class bug where a
    # district exists in-game but was never mapped (it would silently parent-walk to a wrong answer
    # or to nothing). An unexpected nil (not in KNOWN_UNMAPPED) is a hard failure.
    mp = {e["gamePath"]: (e["district"], e["subdistrict"]) for e in entries}
    by_path = {g["path"]: g for g in game}

    def resolve(path):
        seen, hops, cur = set(), 0, path
        while cur and cur not in seen:
            seen.add(cur)
            if cur in mp:
                return mp[cur], hops
            hops += 1
            par = (by_path.get(cur) or {}).get("parentDistrict")
            cur = par if (par and par != "0") else None
        return None, hops

    audit, nils = [], []
    for g in game:
        res, hops = resolve(g["path"])
        audit.append((g["enumName"], g["path"], res, hops))
        if res is None and g["path"] not in KNOWN_UNMAPPED:
            nils.append(g["path"])
    for p in nils:
        errs.append(f"reachability: {p} resolves to NO api district (add a mapping or KNOWN_UNMAPPED)")
    write_audit(audit)

    print(f"entries: {len(entries)}")
    print(f"verify errors: {errs or 'NONE'}")
    print(f"uncovered API districts: {miss_d or 'none'}")
    print(f"uncovered canonical API subdistricts: {miss_s or 'none'}")
    print(f"API entries with no game enum (should be empty; casino is SKIPped): {unexpected or 'none'}")
    print(f"reachability: {len(game)} game districts, {sum(1 for a in audit if a[2])} resolve, "
          f"{sum(1 for a in audit if not a[2])} nil ({len(nils)} unexpected)")

    entries.sort(key=lambda x: (x["district"], x["subdistrict"], x["gameEnum"]))
    json.dump({"_note": "Generated + verified by build-district-map.py. Do not hand-edit.",
               "entryCount": len(entries), "entries": entries},
              open(os.path.join(HERE, "district-map.json"), "w", encoding="utf-8"),
              indent=2, ensure_ascii=False)

    write_reds(entries, api)

    if errs or miss_d or miss_s or unexpected:
        print("FAILED", file=sys.stderr)
        sys.exit(1)
    print("OK: generated district-map.json + NCZoningDistricts.reds")


def write_audit(audit):
    """Human-readable reachability report: every game district -> resolved API name (via the
    simulated Layer-2 parent walk), hop count, so a reviewer can eyeball for wrong resolutions."""
    lines = ["# District reachability audit (generated by build-district-map.py). Do not hand-edit.",
             "# game enum | game path | -> API district / subdistrict | parent-hops (0 = direct)",
             ""]
    for en, path, res, hops in sorted(audit, key=lambda a: (a[2] is None, a[0])):
        if res is None:
            tgt = "*** NIL (no api district) ***"
        else:
            tgt = res[0] + (" / " + res[1] if res[1] else "")
        lines.append(f"{en:34s} {path:34s} -> {tgt:42s} hops={hops}")
    open(os.path.join(HERE, "district-resolution-audit.txt"), "w", encoding="utf-8",
         newline="\n").write("\n".join(lines) + "\n")


def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def write_reds(entries, api):
    version = read_version()
    # The vocabulary, A-Z. ALL subdistricts, canonical or not (see the module docstring).
    districts = sorted(d["name"] for d in api)
    subs = {d["name"]: sorted(s["name"] for s in (d.get("subdistricts") or [])) for d in api}
    nsubs = sum(len(v) for v in subs.values())

    lines = [
        "// ======================================================================================",
        "// Mod Name: NCZoningCore",
        "// File: NCZoningDistricts.reds",
        "// Author: Spuddeh",
        "// Description: GENERATED - do not hand-edit. Two things, both derived from /v1/districts:",
        "//                1. Lookup()  - the static (Layer 1) map from the game's district TweakDBID",
        "//                   (District.GetDistrictID()) to the NC Zoning API district / subdistrict",
        "//                   strings, for the editorial cases where the two vocabularies differ.",
        "//                2. AllDistricts() / SubdistrictsOf() - the API's district VOCABULARY,",
        "//                   enumerable. Static, so it needs no network and no registry data: a",
        "//                   consumer can render a district picker before the fetch lands, and an",
        "//                   area with ZERO locations still appears (deriving the list from the",
        "//                   locations would silently hide it).",
        "//              Regenerate + verify with tools/districts/build-district-map.py.",
        f"// Mod Version: {version} (Pre-release)",
        "// ======================================================================================",
        "",
        "module NCZoning.Api",
        "",
        "public class NCZDistrictName {",
        "  public let district: String;",
        "  public let subdistrict: String;   // \"\" for a top-level district",
        "}",
        "",
        "public class NCZDistrictMap {",
        "  // The game's current district TweakDBID -> API district/subdistrict. Returns null when",
        "  // the game district is not directly on the map; the caller walks up the parent chain",
        "  // (Layer 2) and retries. " + str(len(entries)) + " entries, verified against /v1/districts.",
        "  public static func Lookup(gameDistrict: TweakDBID) -> ref<NCZDistrictName> {",
    ]
    for e in entries:
        lines.append(f'    if gameDistrict == t"{e["gamePath"]}" {{ return NCZDistrictMap.Make("{esc(e["district"])}", "{esc(e["subdistrict"])}"); }}')
    lines += [
        "    return null;",
        "  }",
        "",
        f"  // The {len(districts)} API districts, A-Z. Includes districts with no locations yet.",
        "  public static func AllDistricts() -> array<String> {",
        "    let out: array<String>;",
    ]
    for d in districts:
        lines.append(f'    ArrayPush(out, "{esc(d)}");')
    lines += [
        "    return out;",
        "  }",
        "",
        f"  // The subdistricts of `district`, A-Z ({nsubs} in total). Empty for a district with none",
        "  // (Dogtown, NCX Spaceport / Morro Rock) and for an unknown district.",
        "  public static func SubdistrictsOf(district: String) -> array<String> {",
        "    let out: array<String>;",
    ]
    for d in districts:
        if not subs[d]:
            continue
        lines.append(f'    if UnicodeStringEqual(district, "{esc(d)}") {{')
        for s in subs[d]:
            lines.append(f'      ArrayPush(out, "{esc(s)}");')
        lines.append("      return out;")
        lines.append("    }")
    lines += [
        "    return out;",
        "  }",
        "",
        "  private static func Make(district: String, subdistrict: String) -> ref<NCZDistrictName> {",
        "    let r = new NCZDistrictName();",
        "    r.district = district;",
        "    r.subdistrict = subdistrict;",
        "    return r;",
        "  }",
        "}",
        "",
    ]
    open(REDS, "w", encoding="utf-8", newline="\n").write("\n".join(lines))


if __name__ == "__main__":
    main()
