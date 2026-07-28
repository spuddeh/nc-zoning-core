// ======================================================================================
// Mod Name: NCZoningCore
// File: NCZInstalled.reds
// Author: Spuddeh
// Description: Which registry locations are actually INSTALLED on this machine.
//
//              WHY THIS NEEDS CET, AND WHY THAT IS NOT A CORE DEPENDENCY. Detection
//              means asking whether a mod's .archive / .xl files are present in
//              archive/pc/mod/, and NOTHING REACHABLE FROM REDSCRIPT CAN LOOK THERE:
//              RedFileSystem confines every mod to r6/storages/<name>/, and the engine
//              exposes no archive surface to script at all (the string "Archive" does not
//              appear anywhere in the RTTI dump). CET's Lua has ModArchiveExists(name),
//              measured working 2026-07-28, and it is the only route available today.
//
//              So the scan is done by a bundled CET Lua component that pushes its results
//              in here through BeginScan / ReportInstalled / EndScan. Without CET the
//              component never runs, this registry stays empty, IsAvailable() is false and
//              every query answers Unknown. NCZoningCore itself still has no CET
//              dependency: consumers read redscript and never touch Lua.
//
//              IN-MEMORY AND PER-SESSION. Deliberately NOT persisted. Install state
//              changes between sessions - that is the entire point of it - so a cached
//              answer would go stale in the one direction that matters, telling a player a
//              mod is present after they removed it. The scan is a few hundred filesystem
//              existence checks; it is cheaper to redo than to invalidate correctly.
//
//              THREE STATES, AND THE THIRD IS NOT A ROUNDING ERROR. An empty archives list
//              means "cannot say", never "not installed": it is either an AMM mod, which is
//              PERMANENTLY undetectable because CET sandboxes its own mods folder, or a
//              record the API has not filled yet. Those are indistinguishable from here.
//              Collapsing Unknown into NotInstalled would tell players to download mods
//              they already have.
// Mod Version: 0.3.0 (Pre-release)
// Credits: Spuddeh
// ======================================================================================

module NCZoning.Core

import NCZoning.Data.*

// NCZInstallState lives in NCZoning.Data, not here. It is part of the PUBLIC contract - a
// consumer must be able to name it - and consumers never import NCZoning.Core. Redscript also
// requires a function's return type to be imported even when it is never written out, so an
// enum in an internal module would make GetInstallState uncallable.

public class NCZInstalledRegistry extends ScriptableService {
  // Location ids confirmed present this session. Ids, not archive names - the matching is
  // done in Lua, and this side never learns which file matched.
  private let m_installed: array<String>;
  // False until a scan completes. Distinguishes "scanned, found nothing" from "never
  // scanned", which is the difference between NotInstalled and Unknown for every record.
  private let m_available: Bool;
  private let m_scanning: Bool;
  private let m_scanned: Int32;

  public final static func Get() -> ref<NCZInstalledRegistry> {
    return GameInstance.GetScriptableServiceContainer()
      .GetService(n"NCZoning.Core.NCZInstalledRegistry") as NCZInstalledRegistry;
  }

  // --- written by the CET component ----------------------------------------------------

  // Clears any previous result. A re-scan mid-session is allowed (the player may have
  // alt-tabbed and changed nothing, but the cost of permitting it is nil).
  public func BeginScan() -> Void {
    ArrayClear(this.m_installed);
    this.m_scanning = true;
    this.m_available = false;
    this.m_scanned = 0;
  }

  // One call per location found installed. Ids are pushed individually rather than as one
  // array: marshalling an array<String> across the CET boundary is the fragile part of this
  // path, and a few hundred String calls are not.
  public func ReportInstalled(locationId: String) -> Void {
    if !this.m_scanning || StrLen(locationId) == 0 {
      return;
    }
    if !ArrayContains(this.m_installed, locationId) {
      ArrayPush(this.m_installed, locationId);
    }
  }

  // `scanned` is how many records the component actually tested, for the log only. A scan
  // that ends having tested zero records still counts as available - it means the registry
  // was empty, not that detection failed.
  public func EndScan(scanned: Int32) -> Void {
    this.m_scanning = false;
    this.m_available = true;
    this.m_scanned = scanned;
    NCZoningLog(s"install scan complete: \(ArraySize(this.m_installed)) installed of \(scanned) tested");
  }

  // --- read by consumers ---------------------------------------------------------------

  public func IsAvailable() -> Bool {
    return this.m_available;
  }

  public func InstalledCount() -> Int32 {
    return ArraySize(this.m_installed);
  }

  // The whole contract in one function. Note the order of the guards: availability is
  // checked FIRST, so with no CET everything answers Unknown rather than NotInstalled.
  public func StateOf(loc: ref<NCZLocation>) -> NCZInstallState {
    if !this.m_available || !IsDefined(loc) {
      return NCZInstallState.Unknown;
    }
    if ArrayContains(this.m_installed, loc.Id()) {
      return NCZInstallState.Installed;
    }
    // Nothing to test against. AMM mods live here permanently, so this is genuinely
    // unknowable rather than merely unknown-so-far.
    if loc.ArchiveCount() == 0 {
      return NCZInstallState.Unknown;
    }
    return NCZInstallState.NotInstalled;
  }
}
