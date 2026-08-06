-- ======================================================================================
-- Mod Name: NCZoningCore
-- File: bin/x64/plugins/cyber_engine_tweaks/mods/NCZoningCore/init.lua
-- Author: Spuddeh
-- Description: Installed-mod detection, and the ONLY Lua NCZoningCore ships.
--
--              Detection asks whether a location mod's .archive / .xl files are present in
--              archive/pc/mod/, and nothing reachable from redscript can look there:
--              RedFileSystem confines every mod to r6/storages/<name>/, and the engine
--              exposes no archive surface to script - the string "Archive" does not occur
--              anywhere in the RTTI dump. CET's ModArchiveExists(name) is the only route.
--
--              CET STAYS OPTIONAL. Without it this file never runs, the redscript registry
--              stays empty, IsInstallDetectionAvailable() answers false and every location
--              reads Unknown. NCZoningCore takes no CET dependency, and redscript consumers
--              never touch Lua.
--
--              RESULTS ARE NOT PERSISTED, here or on the redscript side. Install state is
--              what changes between sessions, so a cached answer would claim a mod is
--              present after the player removed it.
-- Mod Version: 1.1.0
-- Credits: Spuddeh
-- ======================================================================================

local scanned = false

-- Guarded exactly like the consumer example: this file is inert rather than broken if
-- NCZoningCore's redscript half is absent or too old.
local function hasNCZ()
  return NCZoningApi ~= nil and NCZoningApi.ApiVersion and NCZoningApi.ApiVersion() >= 1
end

local function scan(reason)
  if scanned or not hasNCZ() or not NCZoningApi.IsReady() then return end
  if NCZoningApi.BeginInstallScan == nil then
    -- Core's redscript half is older than 1.0.0. Say so once rather than erroring on every call.
    print("[NCZoningCore] install detection needs NCZoningCore 1.0.0+ - skipping")
    scanned = true
    return
  end
  scanned = true

  local locations = NCZoningApi.GetAllLocations()   -- array<ref<NCZLocation>> -> 1-indexed table
  NCZoningApi.BeginInstallScan()

  local tested, found = 0, 0
  for _, loc in ipairs(locations) do
    local n = loc:ArchiveCount()
    if n > 0 then
      tested = tested + 1
      -- ANY match counts. A player who installed the main archive but none of the mod's
      -- optional archives still has the mod.
      for i = 0, n - 1 do
        if ModArchiveExists(loc:ArchiveAt(i)) then
          NCZoningApi.ReportInstalled(loc:Id())
          found = found + 1
          break
        end
      end
    end
    -- n == 0 is deliberately NOT tested and NOT reported. An empty archives list means
    -- "cannot say" - an AMM mod, whose files live in CET's own sandboxed folder and can never
    -- be seen by any mod, or a record the API has not filled yet. Reporting those as
    -- not-installed would tell players to download mods they already have.
  end

  NCZoningApi.EndInstallScan(tested)
  print(("[NCZoningCore] install scan (%s): %d installed of %d detectable, %d total")
    :format(reason, found, tested, #locations))
end

registerForEvent("onInit", function()
  if NCZoningApi == nil then
    -- Not an error. This Lua ships WITH the framework, so a missing NCZoningApi means the
    -- redscript half failed to compile - which the redscript log will already be shouting about.
    return
  end

  -- The registry is fetched asynchronously, so the scan waits for data rather than racing it.
  -- isRefresh is ignored on purpose: a later network refresh re-sends the same records with the
  -- same archive names, and a running game cannot change what is in archive/pc/mod/.
  Observe("NCZoningApi", "OnDataReady", function(_, _, _, isRefresh)
    scan(isRefresh and "refresh" or "ready")
  end)

  -- No data, ever, this session (no RedHttpClient and no hand-supplied snapshot). Nothing to
  -- scan against, so stop rather than leaving detection permanently "pending".
  Observe("NCZoningApi", "OnDataError", function(_, reason)
    if not NCZoningApi.IsReady() then
      scanned = true
      print(("[NCZoningCore] no registry this session (%s) - install detection skipped")
        :format(tostring(reason)))
    end
  end)

  -- The store can already be ready before this subscribes, when the offline cache loads first.
  if NCZoningApi.IsReady() then
    scan("already-ready")
  end
end)
