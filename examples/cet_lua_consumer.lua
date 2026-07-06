-- ======================================================================================
-- EXAMPLE - CET Lua consumer of NCZoningCore. Teaching reference, not a shipped file.
-- Drop this into a CET mod's init.lua (or require it) as a starting point.
--
-- Verified interop facts this is built on:
--   * NCZoningCore exposes a bare-named facade class `NCZoningApi`. Call its STATIC methods
--     with a dot:  NCZoningApi.GetAllLocations()  (NOT the internal service).
--   * Each location is a handle; call its methods with a colon:  loc:Name(), loc:Pos().
--   * A reds array<T> arrives as a 1-indexed Lua table -> use ipairs / #.
--   * "Data ready" is delivered by OBSERVING an instance method (custom CallbackSystem
--     events are not delivered to Lua):  Observe('NCZoningApi', 'OnDataReady', fn).
--   * As a fallback you can just poll  NCZoningApi.IsReady().
-- ======================================================================================

-- Soft dependency: everything is guarded so your mod still runs without NCZoningCore.
local function hasNCZ()
  return NCZoningApi ~= nil and NCZoningApi.ApiVersion and NCZoningApi.ApiVersion() >= 1
end

local function useTheData(reason)
  if not hasNCZ() or not NCZoningApi.IsReady() then return end
  print(("[consumer] using registry (%s): %d locations, dataset=%s")
    :format(reason, NCZoningApi.GetLocationCount(), tostring(NCZoningApi.GetDataVersion())))

  -- "Nearby toast" demo: registry locations within 50 m of the player.
  local player = Game.GetPlayer()
  if player then
    local pos = player:GetWorldPosition()
    local near = NCZoningApi.GetLocationsNear(pos, 50.0)   -- array<ref<NCZLocation>> -> Lua table
    for _, loc in ipairs(near) do
      print(("[consumer] near: '%s' by %s in %s"):format(loc:Name(), loc:NexusId(), loc:District()))
    end
  end

  -- "District guide" demo: how many registry locations are in a district (API vocabulary).
  -- For the PLAYER's current district, read it from the game's DistrictManager and map it to
  -- the API's spaced name - NCZoningCore does not ship district geometry.
  local watson = NCZoningApi.GetLocationsByDistrict("Watson")
  print(("[consumer] Watson has %d registry locations"):format(#watson))
end

registerForEvent("onInit", function()
  if NCZoningApi == nil then
    print("[consumer] NCZoningCore not installed - running without it")
    return
  end

  -- Preferred: react to the data-ready signal. The callback args are
  -- (self, count, datasetVersion, isRefresh). isRefresh=false on first load, true on a
  -- later network refresh.
  Observe("NCZoningApi", "OnDataReady", function(_, count, datasetVersion, isRefresh)
    print(("[consumer] OnDataReady: count=%d refresh=%s"):format(count, tostring(isRefresh)))
    useTheData(isRefresh and "refresh" or "ready")
  end)

  -- Also handle the case where the store was already ready before we subscribed
  -- (e.g. the offline cache loaded first).
  if NCZoningApi.IsReady() then
    useTheData("already-ready")
  end
end)

-- Fallback pattern if you prefer polling over Observe: uncomment this and delete the Observe.
-- local done = false
-- registerForEvent("onUpdate", function()
--   if not done and hasNCZ() and NCZoningApi.IsReady() then
--     done = true
--     useTheData("poll")
--   end
-- end)
