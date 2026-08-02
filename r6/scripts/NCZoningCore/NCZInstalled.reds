// ======================================================================================
// Mod Name: NCZoningCore
// File: NCZInstalled.reds
// Author: Spuddeh
// Description: Which registry locations are installed on this machine.
//
//              Detection asks whether a mod's .archive / .xl files are present in
//              archive/pc/mod/, and nothing reachable from redscript can look there:
//              RedFileSystem confines every mod to r6/storages/<name>/, and the engine
//              exposes no archive surface to script (the string "Archive" does not appear
//              anywhere in the RTTI dump). CET's Lua ModArchiveExists(name) is the only
//              route, so the scan runs in the bundled CET Lua component and pushes its
//              results in here through BeginScan / ReportInstalled / EndScan.
//
//              CET STAYS OPTIONAL. Without it the component never runs, this registry stays
//              empty, IsAvailable() is false and every query answers Unknown. NCZoningCore
//              takes no CET dependency, and consumers never touch Lua.
//
//              IN-MEMORY AND PER-SESSION, never persisted. Install state is what changes
//              between sessions, so a cached answer would claim a mod is present after the
//              player removed it.
//
//              THREE STATES. An empty archives list means "cannot say", never "not
//              installed": it is either an AMM mod, permanently undetectable because CET
//              sandboxes its own mods folder, or a record the API has not filled yet. Those
//              are indistinguishable from here, so both read Unknown.
// Mod Version: 0.3.0 (Pre-release)
// Credits: Spuddeh
// ======================================================================================

module NCZoning.Core

import NCZoning.Data.*

// NCZInstallState lives in NCZoning.Data, not here: it is part of the public contract, and
// consumers never import NCZoning.Core. Redscript also requires a function's return type to be
// imported even when it is never written out, so an enum in an internal module would make
// GetInstallState uncallable.

public class NCZInstalledRegistry extends ScriptableService {
  // Location ids confirmed present this session. Ids, not archive names - the matching is
  // done in Lua, and this side never learns which file matched.
  private let m_installed: array<String>;
  // False until a scan completes. Separates "scanned, found nothing" from "never scanned",
  // which is the difference between NotInstalled and Unknown for every record.
  private let m_available: Bool;
  private let m_scanning: Bool;
  private let m_scanned: Int32;

  public final static func Get() -> ref<NCZInstalledRegistry> {
    return GameInstance.GetScriptableServiceContainer()
      .GetService(n"NCZoning.Core.NCZInstalledRegistry") as NCZInstalledRegistry;
  }

  // --- written by the CET component ----------------------------------------------------

  // Clears any previous result. A re-scan mid-session is allowed.
  public func BeginScan() -> Void {
    ArrayClear(this.m_installed);
    this.m_scanning = true;
    this.m_available = false;
    this.m_scanned = 0;
  }

  // One call per location found installed. Ids are pushed individually rather than as one
  // array: passing an array<String> across the CET boundary is the fragile part of this
  // route, and a few hundred String calls are not.
  public func ReportInstalled(locationId: String) -> Void {
    if !this.m_scanning || StrLen(locationId) == 0 {
      return;
    }
    if !ArrayContains(this.m_installed, locationId) {
      ArrayPush(this.m_installed, locationId);
    }
  }

  // Marks detection answerable and fires NCZoning-InstallScanComplete, which is a consumer's
  // only signal that the scan has finished.
  //
  // `scanned` is how many records the component tested, for the log only. A scan that ends
  // having tested zero records still counts as available: it means the registry was empty, not
  // that detection failed.
  //
  // Reached from CET Lua via NCZoningApi.EndInstallScan, which runs on the game thread - the
  // condition NCZoningDataEvent.Dispatch requires.
  public func EndScan(scanned: Int32) -> Void {
    this.m_scanning = false;
    this.m_available = true;
    this.m_scanned = scanned;
    NCZoningLog(s"install scan complete: \(ArraySize(this.m_installed)) installed of \(scanned) tested");
    NCZoningDataEvent.Dispatch(n"NCZoning-InstallScanComplete", "", ArraySize(this.m_installed), "");
  }

  // --- read by consumers ---------------------------------------------------------------

  public func IsAvailable() -> Bool {
    return this.m_available;
  }

  public func InstalledCount() -> Int32 {
    return ArraySize(this.m_installed);
  }

  // Guard order matters: availability is checked FIRST, so with no CET everything answers
  // Unknown rather than NotInstalled.
  public func StateOf(loc: ref<NCZLocation>) -> NCZInstallState {
    if !this.m_available || !IsDefined(loc) {
      return NCZInstallState.Unknown;
    }
    if ArrayContains(this.m_installed, loc.Id()) {
      return NCZInstallState.Installed;
    }
    // Nothing to test against - an AMM mod, or a record the API has not filled yet.
    if loc.ArchiveCount() == 0 {
      return NCZInstallState.Unknown;
    }
    return NCZInstallState.NotInstalled;
  }
}
