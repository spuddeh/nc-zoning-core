// ======================================================================================
// Mod Name: NCZoningCore
// File: translations/French.reds
// Author: Spuddeh
// Description: The French slot. Empty - every string shows in English until someone
//              fills this in. Filling it in is welcome, and takes no coding.
//
//              TO TRANSLATE - three steps:
//
//                1. Open English.reds and copy ONLY the this.Text(...) lines.
//                   NOT the whole file. Copying the file brings the English
//                   class name with it, and two classes with one name stops
//                   EVERY redscript mod on the player's machine from loading.
//                2. Paste them below, over the "translations go here" line.
//                   Leave everything else in this file exactly as it is.
//                3. Translate the SECOND text on each line. Never change the first.
//
//              this.Text("NCZ.statusNoData",  "NC Zoning: no data.");
//                        ^^^^^^^^^^^^^^^^^^  the KEY - never change it
//                                             ^^^^^^^^^^^^^^^^^^^^^  translate this
//
//              RULES:
//                - Partial is fine. Anything you leave out falls back to English.
//                - Keep {file} exactly as written. It is replaced with a filename at
//                  runtime, and it may go anywhere in the sentence.
//
//              Then it ships as its own mod - one file, and nothing has to be
//              released at this end. Full instructions, including how to package
//              and upload it:
//              https://github.com/spuddeh/nc-zoning-core/blob/main/docs/TRANSLATING.md
//
//              MAINTAINER: empty on purpose - a filled slot would override newer
//              English wording. The path, module and class name are public API,
//              because a translation mod REPLACES this file.
// Mod Version: 1.2.0
// Credits: psiberx (Codeware)
// ======================================================================================

module NCZoning.Translations

import Codeware.Localization.*

public class NCZ_French extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    // Usable data that can never refresh. Informational, not an error.
    this.Text("NCZ.statusSnapshot",    "NC Zoning: utilisation d'un instantané local. Impossible d'actualiser sans RedHttpClient.");
    this.Text("NCZ.statusUnreadable",  "NC Zoning: {file} est illisible. Téléchargez-le à nouveau – consultez la page du mod.");
    // Fetch failed with the network layer present.
    this.Text("NCZ.statusFetchFailed", "NC Zoning: impossible de télécharger le registre des emplacements et aucune copie locale n'existe. Consultez la page du mod.");
    // No network layer and no hand-supplied file.
    this.Text("NCZ.statusNoData",      "NC Zoning: aucune donnée de localisation. Installez RedHttpClient ou téléchargez {file} manuellement – consultez la page du mod.");

    // --- area names ------------------------------------------------------------------
    // ONE KEY, not thirty-six. LocalizeArea names an area from the game's own district record,
    // so every district and subdistrict is already translated wherever the game is. The casino
    // is a registry POI with no district record behind it, so it is the only area name that has
    // to live here.
    //
    // "North Oak", not "North Oaks". The game's own name for the district is LocKey#10967,
    // singular, and it reads that way 47 times against 1 across every string the game ships -
    // the one plural is two characters typing at each other in a shard. Only the TweakDB path is
    // plural (Districts.NorthOaks), and no player sees a TweakDB path.
    this.Text("NCZ.area.northOaksCasino", "Casino de North Oak");
  }
}
