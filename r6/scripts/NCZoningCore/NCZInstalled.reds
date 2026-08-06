// ======================================================================================
// Mod Name: NCZoningCore
// File: NCZInstalled.reds
// Author: Spuddeh
// Description: Which registry locations are installed on this machine.
//
//              Detection asks whether a mod's .archive / .xl files are mounted.
//              RedFunc.ArchiveExists answers from the engine's ResourceDepot, so a REDmod
//              folder, a classic archive/pc/mod install and a runtime-mounted archive all
//              answer alike, and a file that is present but failed to load answers false.
//              The name may carry the .archive extension or omit it, and case does not
//              matter, so registry names are passed through untouched.
//
//              RedFunctions is a HARD dependency, so the import is unguarded. Detection is
//              therefore always answerable, and IsAvailable() reports whether the scan has
//              RUN - not whether it is possible.
//
//              IN-MEMORY AND PER-SESSION, never persisted. Install state is what changes
//              between sessions, so a cached answer would claim a mod is present after the
//              player removed it.
//
//              THREE STATES. An empty archives list means "cannot say", never "not
//              installed": it is either an AMM mod, whose files are not archives at all and
//              so can never be seen this way, or a record the API has not filled yet. Those
//              are indistinguishable from here, so both read Unknown.
// Mod Version: 1.1.0
// Credits: Spuddeh
// ======================================================================================

module NCZoning.Core

import NCZoning.Data.*
import RedFunctions.*

// NCZInstallState lives in NCZoning.Data, not here: it is part of the public contract, and
// consumers never import NCZoning.Core. Redscript also requires a function's return type to be
// imported even when it is never written out, so an enum in an internal module would make
// GetInstallState uncallable.

public class NCZInstalledRegistry extends ScriptableService {
  // Location ids confirmed present this session. Ids, not archive names - which file matched
  // is not something any consumer has asked for.
  private let m_installed: array<String>;
  // False until a scan completes. Separates "scanned, found nothing" from "never scanned",
  // which is the difference between NotInstalled and Unknown for every record.
  private let m_available: Bool;
  private let m_scanned: Int32;

  public final static func Get() -> ref<NCZInstalledRegistry> {
    return GameInstance.GetScriptableServiceContainer()
      .GetService(n"NCZoning.Core.NCZInstalledRegistry") as NCZInstalledRegistry;
  }

  // --- the scan ------------------------------------------------------------------------

  // Called on NCZoning-DataReady, and runs once per session.
  //
  // A later network refresh re-sends the same records with the same archive names, and a
  // running game cannot change what is mounted - so a re-scan would answer identically for
  // every record it already tested. A refresh that ADDS records leaves those untested and
  // reading Unknown until the next launch; the per-call cost of ArchiveExists is unmeasured,
  // so that is not traded for a mid-session sweep yet.
  //
  // Dispatches NCZoning-InstallScanComplete, which is a consumer's only signal that
  // detection has an answer. Must run on the game thread - the condition
  // NCZoningDataEvent.Dispatch requires.
  public func ScanOnce() -> Void {
    if this.m_available {
      return;
    }
    let svc = NCZoningService.Get();
    if !IsDefined(svc) {
      return;
    }

    ArrayClear(this.m_installed);
    // Bound before ArraySize: applying it directly to a method that returns an array reads
    // garbage in redscript.
    let all = svc.GetAllLocations();
    let total = ArraySize(all);
    let tested = 0;
    let i = 0;
    while i < total {
      let loc = all[i];
      let archives = loc.ArchiveCount();
      // An empty archives list is deliberately NOT tested and NOT recorded. It means "cannot
      // say", and recording it as absent would tell players to download mods they already have.
      if archives > 0 {
        tested += 1;
        // ANY match counts. A player who installed the main archive but none of the mod's
        // optional archives still has the mod.
        let found = false;
        let j = 0;
        while j < archives && !found {
          if RedFunc.ArchiveExists(loc.ArchiveAt(j)) {
            found = true;
          }
          j += 1;
        }
        if found {
          ArrayPush(this.m_installed, loc.Id());
        }
      }
      i += 1;
    }

    this.m_available = true;
    this.m_scanned = tested;
    NCZoningLog(s"install scan: \(ArraySize(this.m_installed)) installed of \(tested) detectable, \(total) total");
    NCZoningDataEvent.Dispatch(n"NCZoning-InstallScanComplete", "", ArraySize(this.m_installed), "");
  }

  // --- read by consumers ---------------------------------------------------------------

  public func IsAvailable() -> Bool {
    return this.m_available;
  }

  public func InstalledCount() -> Int32 {
    return ArraySize(this.m_installed);
  }

  // Guard order matters: the scan-has-run check is FIRST, so anything asked before the scan
  // answers Unknown rather than NotInstalled.
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
