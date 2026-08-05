// ======================================================================================
// Mod Name: NCZoningCore
// File: Loc.reds
// Author: Spuddeh
// Description: How the status sentences are read. NCZ_T is global scope, no module, so
//              NCZStatusMessage (a free function with no GameInstance) can call it with
//              no import.
//
//              READS GO THROUGH Codeware's LocalizationSystem.GetText, NOT the global
//              GetLocalizedText. GetLocalizedText resolves the BASE GAME's text table and
//              returns "" for an NCZ.* key, which would render every sentence as its key.
//
//              GetText NEEDS A GameInstance and the callers have none, so the system is
//              resolved once and cached on a ScriptableService, because
//              GameInstance.GetScriptableServiceContainer() is a static that takes no
//              GameInstance. NCZoningFetcher binds it at Session/Ready.
//
//              A MISSING KEY RENDERS AS THE KEY. Returning "" would make a failure state
//              pass for live data - GetStatusMessage's contract is "" = nothing wrong.
// Mod Version: 1.0.0
// Credits: psiberx (Codeware)
// ======================================================================================

import Codeware.Localization.*
import NCZoning.Core.*

// Holds the LocalizationSystem so a free function can reach it. Global scope, so the service
// name is the bare class name.
public class NCZLocCache extends ScriptableService {
  private let m_loc: ref<LocalizationSystem>;

  public final static func Get() -> ref<NCZLocCache> {
    return GameInstance.GetScriptableServiceContainer().GetService(n"NCZLocCache") as NCZLocCache;
  }

  // Called from NCZoningFetcher.OnSessionReady, which is a ScriptableSystem and therefore has
  // a GameInstance to give. Re-binding on a later session is harmless and keeps this correct
  // across a load.
  public func Bind(gi: GameInstance) -> Void {
    this.m_loc = LocalizationSystem.GetInstance(gi);
    if !IsDefined(this.m_loc) {
      NCZoningLog("[ERROR] Codeware LocalizationSystem not found - status sentences will render as their keys");
    }
  }

  public func Text(key: String) -> String {
    if !IsDefined(this.m_loc) {
      return key;
    }
    let s = this.m_loc.GetText(key);
    return StrLen(s) > 0 ? s : key;
  }
}

public func NCZ_T(key: String) -> String {
  let cache = NCZLocCache.Get();
  if !IsDefined(cache) {
    return key;
  }
  return cache.Text(key);
}

// Substitutes one placeholder. The sentences live whole in the translation file so a
// translator controls word order.
public func NCZ_T1(key: String, token: String, value: String) -> String {
  return StrReplace(NCZ_T(key), token, value);
}
