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
    // A fetch failed after retries. IsReady() may still be true if the offline cache served.
    NCZLog(s"[consumer] DataError (\(event.Reason())); ready=\(IsReady())");
  }

  private func UseTheData() -> Void {
    // "Nearby toast" demo: find registry locations within 50 m of the player.
    let player = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject();
    if !IsDefined(player) {
      return;
    }
    // NOTE the rvalue-array bug: never ArraySize()/index a method's array return inline -
    // bind it to a local first (see the NCZoningCore wiki).
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
  }
}

// Dev-only log wrapper for this example (uses Codeware's FTLog). Strip for release.
@if(ModuleExists("NCZoning.Api"))
public func NCZLog(value: script_ref<String>) -> Void {
  FTLog(s"\(value)");
}
