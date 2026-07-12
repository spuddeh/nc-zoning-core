// ======================================================================================
// EXAMPLE - redscript consumer of NCZoningCore. Teaching reference, not a shipped file.
//
// Shows the soft-dependency pattern: this file compiles to NOTHING when NCZoningCore is not
// installed (every top-level item is guarded by @if(ModuleExists("NCZoning.Api"))), so your
// mod still loads without it. For a HARD dependency, drop the @if guards and just
// `import NCZoning.Api.*` - a missing framework then becomes a compile error naming it.
// ======================================================================================

// --- imports (guarded) ---------------------------------------------------------------
// NCZoning.Api  = the public read API (free functions).
// NCZoning.Data = the DTO + event payload types (NCZLocation, NCZoningDataEvent).
@if(ModuleExists("NCZoning.Api"))
import NCZoning.Api.*
@if(ModuleExists("NCZoning.Api"))
import NCZoning.Data.*

@if(ModuleExists("NCZoning.Api"))
public class MyNCZConsumer extends ScriptableSystem {

  private func OnAttach() -> Void {
    // Version handshake. redscript has no dependency versioning and ModuleExists() can't
    // check a version, so gate on ApiVersion() (it increments only on a breaking change).
    if ApiVersion() < 1 {
      return;   // framework too old for what this consumer expects
    }

    // Subscribe to the three lifecycle events. Names are the frozen public strings.
    let cs = GameInstance.GetCallbackSystem();
    cs.RegisterCallback(n"NCZoning-DataReady", this, n"OnDataReady").SetLifetime(CallbackLifetime.Forever);
    cs.RegisterCallback(n"NCZoning-DataRefreshed", this, n"OnDataRefreshed").SetLifetime(CallbackLifetime.Forever);
    cs.RegisterCallback(n"NCZoning-DataError", this, n"OnDataError").SetLifetime(CallbackLifetime.Forever);

    // If the store is already ready (e.g. this system attached after the offline cache
    // loaded), use it right away - the event may have fired before we subscribed.
    if IsReady() {
      this.UseTheData();
    }
  }

  // The event payload is a ref<NCZoningDataEvent> (from NCZoning.Data).
  private cb func OnDataReady(event: ref<NCZoningDataEvent>) -> Void {
    NCZLog(s"[consumer] DataReady: \(event.Count()) locations, dataset=\(event.DatasetVersion())");
    this.UseTheData();
  }
  private cb func OnDataRefreshed(event: ref<NCZoningDataEvent>) -> Void {
    NCZLog(s"[consumer] DataRefreshed: \(event.Count()) locations");
    this.UseTheData();
  }
  private cb func OnDataError(event: ref<NCZoningDataEvent>) -> Void {
    // The registry could not be obtained. Two very different situations:
    //   IsReady() == true  -> informational; the cache is still serving usable data.
    //   IsReady() == false -> FATAL for this session. No data exists and none is coming.
    // The fatal case is normal, not exotic: RedHttpClient is optional for NCZoningCore, so a
    // user who declined it and never downloaded locations_full.json by hand lands here every
    // launch. Show an empty state that explains itself; do not wait for data that never arrives.
    NCZLog(s"[consumer] DataError (\(event.Reason())); ready=\(IsReady()) http=\(IsHttpAvailable())");
    if !IsReady() {
      // Render GetStatusMessage(), not a zero count. "0 locations here" is a real answer;
      // "no data" is a failure, and a UI that shows the first for the second tells the player a
      // district is empty when the registry never loaded.
      // e.g. this.ShowMyEmptyState(GetStatusMessage());
    }
  }

  private func UseTheData() -> Void {
    // "Nearby toast" demo: find registry locations within 50 m of the player.
    let player = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject();
    if !IsDefined(player) {
      return;
    }
    // NOTE the rvalue-array bug: never ArraySize()/index a method's array return inline -
    // bind it to a local first, as below. Applying an array intrinsic straight to a method's
    // return value reads garbage in redscript. This is a redscript-wide trap, not an NCZ one.
    let near = GetLocationsNear(player.GetWorldPosition(), 50.0);
    let i = 0;
    while i < ArraySize(near) {
      let loc = near[i];
      NCZLog(s"[consumer] near: '\(loc.Name())' by \(loc.NexusId()) in \(loc.District())");
      i += 1;
    }

    // "District guide" demo: how many registry locations are in a district (API vocabulary).
    // To use the PLAYER's current district, read it from the game (DistrictManager) and map
    // it to the API's spaced name - NCZoningCore deliberately does not ship district geometry.
    let watson = GetLocationsByDistrict("Watson");
    NCZLog(s"[consumer] Watson has \(ArraySize(watson)) registry locations");

    // Building a district picker? Enumerate the vocabulary (0.3.0+), do not derive it from the
    // locations: an area with zero locations appears in no location and would silently vanish.
    // These are static, so they also work before the fetch lands and while it is missing.
    let districts = GetDistricts();
    let d = 0;
    while d < ArraySize(districts) {
      let subs = GetSubdistricts(districts[d]);
      let inDistrict = GetLocationsByDistrict(districts[d]);   // NOT the sum of the subdistricts
      NCZLog(s"[consumer] \(districts[d]): \(ArraySize(inDistrict)) locations, \(ArraySize(subs)) subdistricts");
      d += 1;
    }
  }
}

// Dev-only log wrapper for this example (uses Codeware's FTLog). Strip for release.
@if(ModuleExists("NCZoning.Api"))
public func NCZLog(value: script_ref<String>) -> Void {
  FTLog(s"\(value)");
}
