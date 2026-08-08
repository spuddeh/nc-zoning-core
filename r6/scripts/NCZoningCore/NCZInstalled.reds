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
//              only ArchiveXL .xl manifests, which are not mounted archives either; a record
//              the API has not filled yet; or one whose every archive is shared (below).
//              Those are indistinguishable from here, so all read Unknown.
//
//              A SHARED ARCHIVE PROVES NOTHING. Some authors bundle a prop pack into their own
//              download instead of requiring it, so six unrelated mods each ship a copy of
//              proximas_propshop_v4.archive. Install one and that file is mounted, which used
//              to mark all six installed. A name listed by two locations from DIFFERENT Nexus
//              pages is therefore ignored, and only the files unique to one mod are evidence.
//
//              SAME PAGE IS NOT SHARED. One download can add two locations - Watson Tattoo
//              Shops is that shape - and they really are installed together, so the test is
//              two mod PAGES, not two records. A record with no numeric page ("WIP", empty)
//              is its own group, so two unfinished records never pool.
// Mod Version: 1.2.0
// Credits: Spuddeh
// ======================================================================================

module NCZoning.Core

import NCZoning.Data.*
import RedFunctions.*

// NCZInstallState lives in NCZoning.Data, not here: it is part of the public contract, and
// consumers never import NCZoning.Core. Redscript also requires a function's return type to be
// imported even when it is never written out, so an enum in an internal module would make
// GetInstallState uncallable.

// Which mod a record came from, for deciding whether two records sharing an archive are one
// download or two. The Nexus page is the only identity the registry carries that survives a
// record being split in two.
//
// A RECORD WITHOUT A NUMERIC PAGE IS ITS OWN GROUP. nexus_id also holds "WIP" and "Dummy", and
// pooling every one of those under a single key would make their archives look shared with each
// other. Keying on the record id instead means such a record can only ever match itself.
func NCZPageKey(loc: ref<NCZLocation>) -> String {
  let id = loc.NexusId();
  return NCZIsDigits(id) ? "page:" + id : "rec:" + loc.Id();
}

func NCZIsDigits(s: String) -> Bool {
  let n = StrLen(s);
  if n <= 0 {
    return false;
  }
  let i = 0;
  while i < n {
    // StrFindFirst(haystack, needle): the digit string is searched for this character, not the
    // other way round.
    if StrFindFirst("0123456789", StrMid(s, i, 1)) < 0 {
      return false;
    }
    i += 1;
  }
  return true;
}

public class NCZInstalledRegistry extends ScriptableService {
  // Location ids confirmed present this session. Ids, not archive names - which file matched
  // is not something any consumer has asked for.
  private let m_installed: array<String>;
  // Location ids the scan could actually decide: at least one archive that identifies THIS mod
  // and nothing else. Anything absent from here reads Unknown, so the scan and StateOf share
  // one decision instead of re-deriving it from the record and risking a disagreement.
  private let m_tested: array<String>;
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
    ArrayClear(this.m_tested);
    // Bound before ArraySize: applying it directly to a method that returns an array reads
    // garbage in redscript.
    let all = svc.GetAllLocations();
    let total = ArraySize(all);

    // --- pass 1: which archive names identify no single mod --------------------------
    // Every .archive name in the registry, paired with the page it came from. Flat, not
    // de-duplicated: building a distinct list needs an index-of search per entry, and the
    // pairing below already answers the only question being asked. Roughly 465 entries today,
    // so the comparison below is bounded by a number this file can afford twice a session.
    let occName: array<String>;
    let occPage: array<String>;
    let i = 0;
    while i < total {
      let page = NCZPageKey(all[i]);
      let arcs = all[i].ArchiveCount();
      let j = 0;
      while j < arcs {
        let name = StrLower(all[i].ArchiveAt(j));
        if StrEndsWith(name, ".archive") {
          ArrayPush(occName, name);
          ArrayPush(occPage, page);
        }
        j += 1;
      }
      i += 1;
    }

    // A name seen under two different pages cannot say which of them is installed.
    let ambiguous: array<String>;
    let occ = ArraySize(occName);
    let a = 0;
    while a < occ {
      if !ArrayContains(ambiguous, occName[a]) {
        let clash = false;
        let b = a + 1;
        while b < occ && !clash {
          if UnicodeStringEqual(occName[a], occName[b])
             && !UnicodeStringEqual(occPage[a], occPage[b]) {
            clash = true;
          }
          b += 1;
        }
        if clash {
          ArrayPush(ambiguous, occName[a]);
        }
      }
      a += 1;
    }
    if ArraySize(ambiguous) > 0 {
      NCZoningLog(s"install scan: ignoring \(ArraySize(ambiguous)) archive(s) shared across mod pages");
    }

    // --- pass 2: the scan ------------------------------------------------------------
    let k = 0;
    while k < total {
      let loc = all[k];
      let entries = loc.ArchiveCount();
      // How many of this record's names could identify it alone. Zero means the scan has no
      // evidence either way, so the record is not recorded as tested and reads Unknown -
      // recording it as absent would tell players to download a mod they already have.
      let usable = 0;
      let found = false;
      let j = 0;
      // Stops at the first hit: ANY match counts, because a player who installed the main
      // archive but none of the mod's optional ones still has the mod. Leaving early is safe
      // for `usable` too - a hit is itself a usable name, so the > 0 test below still holds.
      while j < entries && !found {
        let raw = loc.ArchiveAt(j);
        let name = StrLower(raw);
        if StrEndsWith(name, ".archive") && !ArrayContains(ambiguous, name) {
          usable += 1;
          // The registry's spelling is passed through untouched: ArchiveExists is
          // case-insensitive and takes the extension either way.
          if RedFunc.ArchiveExists(raw) {
            found = true;
          }
        }
        j += 1;
      }
      if usable > 0 {
        ArrayPush(this.m_tested, loc.Id());
        if found {
          ArrayPush(this.m_installed, loc.Id());
        }
      }
      k += 1;
    }

    this.m_available = true;
    this.m_scanned = ArraySize(this.m_tested);
    NCZoningLog(s"install scan: \(ArraySize(this.m_installed)) installed of \(this.m_scanned) detectable, \(total) total");
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
    // Nothing that could have identified this record alone - an AMM mod, a record listing only
    // .xl manifests, a record the API has not filled yet, or one whose every archive is shared
    // with another mod page. THE SCAN DECIDED THIS, and this reads its answer rather than
    // re-deriving it: the two must never disagree, or a record the scan skipped reads
    // NotInstalled and tells the player to download a mod they already have.
    if !ArrayContains(this.m_tested, loc.Id()) {
      return NCZInstallState.Unknown;
    }
    return NCZInstallState.NotInstalled;
  }
}
