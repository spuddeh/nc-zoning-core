// ======================================================================================
// Mod Name: NCZoningCore
// File: translations/English.reds
// Author: Spuddeh
// Description: The source of truth for every player-facing string - the four status
//              sentences the no-data banner shows and GetStatusMessage() hands to
//              consumers. Codeware's ModLocalizationPackage.
//
//              ADDING A LANGUAGE IS ADDITIVE: copy this file, translate the second
//              argument of every Text() call, extend ModLocalizationPackage under a new
//              name, and add one case to Provider.reds. Never translate the KEY.
//
//              {file} is the registry cache filename (NCZ_LocationsFile), substituted at
//              the call site. Keep the placeholder; never spell the filename out here.
// Mod Version: 1.0.0
// Credits: psiberx (Codeware)
// ======================================================================================

module NCZoning.Translations

import Codeware.Localization.*

public class NCZ_English extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    // Usable data that can never refresh. Informational, not an error.
    this.Text("NCZ.statusSnapshot",    "NC Zoning: использование локальной копии. Без RedHttpClient обновление невозможно.");
    this.Text("NCZ.statusUnreadable",  "NC Zoning: {file} не читается. Загрузите его заново — см. страницу мода.");
    // Fetch failed with the network layer present.
    this.Text("NCZ.statusFetchFailed", "NC Zoning: Не удалось загрузить реестр местоположений, и локальная копия отсутствует. См. страницу мода.");
    // No network layer and no hand-supplied file.
    this.Text("NCZ.statusNoData",      "NC Zoning: Данные о местоположении отсутствуют. Установите RedHttpClient или загрузите файл {file} вручную — см. страницу модификации.");
  }
}