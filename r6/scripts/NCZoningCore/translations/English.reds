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
// Mod Version: 1.1.0
// Credits: psiberx (Codeware)
// ======================================================================================

module NCZoning.Translations

import Codeware.Localization.*

public class NCZ_English extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    // Usable data that can never refresh. Informational, not an error.
    this.Text("NCZ.statusSnapshot",    "NC Zoning: using a local snapshot. It cannot refresh without RedHttpClient.");
    this.Text("NCZ.statusUnreadable",  "NC Zoning: {file} is unreadable. Re-download it - see the mod page.");
    // Fetch failed with the network layer present.
    this.Text("NCZ.statusFetchFailed", "NC Zoning: could not download the location registry, and no local copy exists. See the mod page.");
    // No network layer and no hand-supplied file.
    this.Text("NCZ.statusNoData",      "NC Zoning: no location data. Install RedHttpClient, or download {file} by hand - see the mod page.");

    // --- area names ------------------------------------------------------------------
    // ONE KEY, not thirty-six. LocalizeArea names an area from the game's own district record,
    // so every district and subdistrict is already translated wherever the game is. North Oaks
    // Casino is a registry POI with no district record behind it, so it is the only area name
    // that has to live here.
    this.Text("NCZ.area.northOaksCasino", "North Oaks Casino");
  }
}
