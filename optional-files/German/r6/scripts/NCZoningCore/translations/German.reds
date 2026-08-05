// ======================================================================================
// Mod Name: NCZoningCore
// File: translations/German.reds
// Author: D/Code
// Description: The German translation for every player-facing string - the four status
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

public class NCZ_German extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    // Usable data that can never refresh. Informational, not an error.
    this.Text("NCZ.statusSnapshot",    "NC Zoning: Offline-Ortsdaten werden benutzt. Diese werden ohne RedHttpClient nicht aktualisiert.");
    this.Text("NCZ.statusUnreadable",  "NC Zoning: {file} ist nicht lesbar. Bitte erneut herunterladen - siehe Mod-Seite.");
    // Fetch failed with the network layer present.
    this.Text("NCZ.statusFetchFailed", "NC Zoning: Konnte die Ortsdaten-Datei nicht herunterladen und es existiert keine lokale Kopie. Siehe Mod-Seite.");
    // No network layer and no hand-supplied file.
    this.Text("NCZ.statusNoData",      "NC Zoning: Keine Ortsdaten vorhanden. Bitte RedHttpClient installieren oder {file} von Hand herunterladen - siehe Mod-Seite.");
  }
}