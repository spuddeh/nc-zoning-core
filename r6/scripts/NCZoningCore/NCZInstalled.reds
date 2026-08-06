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
//              THREE STATES. Nothing a query could match means "cannot say", never "not
//              installed": an AMM mod, whose files are not archives at all; a record listing
//              only ArchiveXL .xl manifests, which are not mounted archives either; or a
//              record the API has not filled yet. Those are indistinguishable from here, so
//              all three read Unknown.
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

  // Runs whenever the store changes: the cache load at launch, and again when the network
  // fetch swaps a newer registry in behind it.
  //
  // It re-runs on that swap because the RECORD LIST can grow, not because the answers can
  // change - archives cannot be added to a running game. Scanning only at cache load leaves
  // any record the network added untested, and an untested record with archives reads
  // NotInstalled, which tells the player to download a mod they already have.
  //
  // Dispatches NCZoning-InstallScanComplete, which is a consumer's only signal that
  // detection has an answer. Must run on the game thread - the condition
  // NCZoningDataEvent.Dispatch requires.
  public func Scan() -> Void {
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
      // Nothing a query could match is deliberately NOT tested and NOT recorded. It means
      // "cannot say", and recording it as absent would tell players to download mods they
      // already have. DetectableArchiveCount, not ArchiveCount: a record listing only .xl
      // manifests has archives and is still unmatchable.
      if loc.DetectableArchiveCount() > 0 {
        tested += 1;
        // ANY match counts. A player who installed the main archive but none of the mod's
        // optional archives still has the mod.
        let entries = loc.ArchiveCount();
        let found = false;
        let j = 0;
        while j < entries && !found {
          let name = loc.ArchiveAt(j);
          if StrEndsWith(StrLower(name), ".archive") && RedFunc.ArchiveExists(name) {
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
    // Nothing a query could have matched - an AMM mod, a record listing only .xl manifests,
    // or a record the API has not filled yet. The SAME test the scan skipped on, so the two
    // cannot disagree: a record the scan never tested must never read NotInstalled here.
    if loc.DetectableArchiveCount() == 0 {
      return NCZInstallState.Unknown;
    }
    return NCZInstallState.NotInstalled;
  }
}
