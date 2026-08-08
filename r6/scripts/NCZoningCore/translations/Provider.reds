// ======================================================================================
// Mod Name: NCZoningCore
// File: translations/Provider.reds
// Author: Spuddeh
// Description: Resolves a language code to a package. Nothing registers this: it extends
//              ScriptableSystem, and Codeware's OnAttach queues the registration itself.
//
//              EVERY LANGUAGE THE GAME SHIPS HAS A CASE HERE, and all but English resolve
//              to an empty package that falls through to the English fallback. The case
//              has to exist before a translation can be dropped in, because a translation
//              mod replaces a language FILE and cannot reach this switch.
//              https://github.com/spuddeh/nc-zoning-core/blob/main/docs/TRANSLATING.md
//
//              An unlisted language hits default and gets English, so a code the game
//              adds later degrades rather than breaking.
// Mod Version: 1.2.0
// Credits: psiberx (Codeware)
// ======================================================================================

module NCZoning.Translations

import Codeware.Localization.*

public class NCZ_LocalizationProvider extends ModLocalizationProvider {
  public func GetPackage(language: CName) -> ref<ModLocalizationPackage> {
    switch language {
      case n"en-us":  return new NCZ_English();
      case n"fr-fr":  return new NCZ_French();
      case n"de-de":  return new NCZ_German();
      case n"es-es":  return new NCZ_Spanish();
      case n"es-mx":  return new NCZ_SpanishLatam();
      case n"it-it":  return new NCZ_Italian();
      case n"pt-br":  return new NCZ_Portuguese();
      case n"pl-pl":  return new NCZ_Polish();
      case n"ru-ru":  return new NCZ_Russian();
      case n"ua-ua":  return new NCZ_Ukrainian();
      case n"cz-cz":  return new NCZ_Czech();
      case n"hu-hu":  return new NCZ_Hungarian();
      case n"tr-tr":  return new NCZ_Turkish();
      case n"th-th":  return new NCZ_Thai();
      case n"ar-ar":  return new NCZ_Arabic();
      case n"jp-jp":  return new NCZ_Japanese();
      case n"kr-kr":  return new NCZ_Korean();
      case n"zh-cn":  return new NCZ_ChineseSimplified();
      case n"zh-tw":  return new NCZ_ChineseTraditional();
      default:       return new NCZ_English();
    };
  }

  public func GetFallback() -> CName {
    return n"en-us";
  }
}
