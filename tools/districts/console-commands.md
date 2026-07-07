# District CET console commands

Diagnostics for the NCZoningCore district map, run from the **Cyber Engine Tweaks**
console (open the CET overlay, Console tab). Handy for verifying the map in-game or
while building a Layer-2 resolver in a consumer mod.

## Two paste rules (or the console rejects it)

The CET console flattens a multi-line paste onto **one line**, so:

1. **Paste the one-line form**, not the annotated version.
2. **No `--` comments** in what you paste: once flattened, a `--` comments out the
   rest of the entire command, giving `'end' expected near '<eof>'`.

The annotated blocks below are for reading; paste the one-liner beneath each.

## Key facts these rely on (verified in-game 2026-07-07)

- The reds lookup class is exposed to Lua as **`NCZoning_Api_NCZDistrictMap`**
  (module `NCZoning.Api` -> dots become underscores). Its `.Lookup(TweakDBID)` is a
  static (call with a dot); the result's `.district` / `.subdistrict` read directly.
- Reach the `DistrictManager` through the **field** `ps.districtManager` — there is
  **no `GetDistrictManager()` getter** (calling it errors). `GetCurrentDistrict()`
  and `GetDistrictID()` are real methods.
- `GetDistrictID()` returns the TweakDBID in **path form** (`Districts.Kabuki`),
  which is what the map keys on. `TDBID.ToStringDEBUG(id)` prints that path.

---

## 1. Current district -> API district (the main check)

Reads where the player is and resolves it through the map. Stand in a district and run it.

```lua
-- readable reference (do NOT paste this version):
local ps = Game.GetScriptableSystemsContainer():Get(CName.new("PreventionSystem"))
local d  = ps.districtManager:GetCurrentDistrict()   -- FIELD, not a getter
local id = d:GetDistrictID()                          -- path-form TweakDBID
local r  = NCZoning_Api_NCZDistrictMap.Lookup(id)
print(TDBID.ToStringDEBUG(id), "=>", r and (r.district.."/"..r.subdistrict) or "nil")
```

Paste this:

```lua
local ps=Game.GetScriptableSystemsContainer():Get(CName.new("PreventionSystem")) local d=ps.districtManager:GetCurrentDistrict() local id=d:GetDistrictID() local r=NCZoning_Api_NCZDistrictMap.Lookup(id) print(TDBID.ToStringDEBUG(id),"=>",r and (r.district.."/"..r.subdistrict) or "nil")
```

Example output at the spaceport: `Districts.NCSpaceport => NCX Spaceport / Morro Rock/`
(trailing slash = top-level district, empty subdistrict).

## 2. Table smoke test (feed known district paths)

Confirms the compiled reds table without moving — resolve a batch of TweakDBIDs.
Edit the list as needed.

```lua
for _,p in ipairs({"Districts.Kabuki","Districts.NCSpaceport","Districts.MorroRock","Districts.NCX","Districts.Wellsprings","Districts.NorthOaks","Districts.BiotechnicaFlats"}) do local r=NCZoning_Api_NCZDistrictMap.Lookup(TweakDBID.new(p)) print(p,"=>",r and (r.district.."/"..r.subdistrict) or "nil") end
```

## 3. District display names (resolve LocKeys)

Prints the game's own name for a district's `localizedName` LocKey (from the TweakDB
dump). Used to confirm the API names match the game's labels.

```lua
for _,k in ipairs({"LocKey#87524","LocKey#87525","LocKey#86297"}) do print(k,"=>",Game.GetLocalizedText(k)) end
```

Spaceport trio: `#87524 => Morro Rock`, `#87525 => Night City International and
Translunar`, `#86297 => NCX Spaceport`.

## 4. Full parent stack of the current district (Layer-2 dev)

`DistrictManager.stack` is the resolved current->parent chain. Useful when building the
Layer-2 walk. NOTE: verify the field read / 1-indexing live before relying on it — this
one has not been exercised as thoroughly as 1-3.

```lua
local ps=Game.GetScriptableSystemsContainer():Get(CName.new("PreventionSystem")) local st=ps.districtManager.stack for i=1,#st do local id=st[i]:GetDistrictID() local r=NCZoning_Api_NCZDistrictMap.Lookup(id) print(i,TDBID.ToStringDEBUG(id),"=>",r and (r.district.."/"..r.subdistrict) or "nil") end
```

## 5. Self-discovery probe (when an accessor is unknown)

Defensive probe that tries getter and field forms and prints what works, without
aborting on the first error. This is how the accessors above were found — keep it for
the next unknown native surface. (`try` returns nil on error and moves on.)

```lua
local function try(l,f) local ok,r=pcall(f) print(l,"=>",ok and tostring(r) or ("ERR "..tostring(r))) return ok and r or nil end local ps=Game.GetScriptableSystemsContainer():Get(CName.new("PreventionSystem")) local dm=try("dm.field",function() return ps.districtManager end) or try("dm.getter",function() return ps:GetDistrictManager() end) local d=dm and try("cur",function() return dm:GetCurrentDistrict() end) if d then local id=try("id",function() return d:GetDistrictID() end) if id then try("PATH",function() return TDBID.ToStringDEBUG(id) end) end end
```
