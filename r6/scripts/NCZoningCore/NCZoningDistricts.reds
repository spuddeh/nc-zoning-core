// ======================================================================================
// Mod Name: NCZoningCore
// File: NCZoningDistricts.reds
// Author: Spuddeh
// Description: GENERATED - do not hand-edit. Three things, all derived from /v1/districts:
//                1. Lookup()  - the static (Layer 1) map from the game's district TweakDBID
//                   (District.GetDistrictID()) to the NC Zoning API district / subdistrict
//                   strings, for the cases where the two vocabularies differ.
//                2. AllDistricts() / SubdistrictsOf() - the API's district VOCABULARY,
//                   enumerable. Static, so it needs no network and no registry data: a
//                   consumer can render a district picker before the fetch lands, and an
//                   area with ZERO locations still appears (deriving the list from the
//                   locations would silently hide it).
//                3. RecordIdsFor() - which game district record NAMES an area, for
//                   LocalizeArea(). A DIFFERENT question to Lookup, and not derivable
//                   from it in either direction: a fold like NorthBadlands maps to
//                   Badlands without naming it, and a composite area is named by two
//                   records while the player stands in only one of them.
//              Regenerate + verify with tools/districts/build-district-map.py.
// Mod Version: 1.1.0
// ======================================================================================

module NCZoning.Api

public class NCZDistrictName {
  public let district: String;
  public let subdistrict: String;   // "" for a top-level district
}

public class NCZDistrictMap {
  // The game's current district TweakDBID -> API district/subdistrict. Returns null when
  // the game district is not directly on the map; the caller walks up the parent chain
  // (Layer 2) and retries. 39 entries, verified against /v1/districts.
  public static func Lookup(gameDistrict: TweakDBID) -> ref<NCZDistrictName> {
    if gameDistrict == t"Districts.Badlands" { return NCZDistrictMap.Make("Badlands", ""); }
    if gameDistrict == t"Districts.NorthBadlands" { return NCZDistrictMap.Make("Badlands", ""); }
    if gameDistrict == t"Districts.SouthBadlands" { return NCZDistrictMap.Make("Badlands", ""); }
    if gameDistrict == t"Districts.BiotechnicaFlats" { return NCZDistrictMap.Make("Badlands", "Biotechnica Flats"); }
    if gameDistrict == t"Districts.JacksonPlains" { return NCZDistrictMap.Make("Badlands", "Jackson Plains"); }
    if gameDistrict == t"Districts.LagunaBend" { return NCZDistrictMap.Make("Badlands", "Laguna Bend"); }
    if gameDistrict == t"Districts.NorthSunriseOilField" { return NCZDistrictMap.Make("Badlands", "North Sunrise Oil Field"); }
    if gameDistrict == t"Districts.RattlesnakeCreek" { return NCZDistrictMap.Make("Badlands", "Rattlesnake Creek"); }
    if gameDistrict == t"Districts.RedPeaks" { return NCZDistrictMap.Make("Badlands", "Red Peaks"); }
    if gameDistrict == t"Districts.RockyRidge" { return NCZDistrictMap.Make("Badlands", "Rocky Ridge"); }
    if gameDistrict == t"Districts.SierraSonora" { return NCZDistrictMap.Make("Badlands", "Sierra Sonora"); }
    if gameDistrict == t"Districts.SoCalBorderCrossing" { return NCZDistrictMap.Make("Badlands", "SoCal Border Crossing"); }
    if gameDistrict == t"Districts.VasquezPass" { return NCZDistrictMap.Make("Badlands", "Vasquez Pass"); }
    if gameDistrict == t"Districts.CityCenter" { return NCZDistrictMap.Make("City Center", ""); }
    if gameDistrict == t"Districts.CorpoPlaza" { return NCZDistrictMap.Make("City Center", "Corpo Plaza"); }
    if gameDistrict == t"Districts.Downtown" { return NCZDistrictMap.Make("City Center", "Downtown"); }
    if gameDistrict == t"Districts.Dogtown" { return NCZDistrictMap.Make("Dogtown", ""); }
    if gameDistrict == t"Districts.Heywood" { return NCZDistrictMap.Make("Heywood", ""); }
    if gameDistrict == t"Districts.Glen" { return NCZDistrictMap.Make("Heywood", "The Glen"); }
    if gameDistrict == t"Districts.VistaDelRey" { return NCZDistrictMap.Make("Heywood", "Vista Del Rey"); }
    if gameDistrict == t"Districts.Wellsprings" { return NCZDistrictMap.Make("Heywood", "Wellsprings"); }
    if gameDistrict == t"Districts.NCSpaceport" { return NCZDistrictMap.Make("NCX Spaceport / Morro Rock", ""); }
    if gameDistrict == t"Districts.MorroRock" { return NCZDistrictMap.Make("NCX Spaceport / Morro Rock", ""); }
    if gameDistrict == t"Districts.NCX" { return NCZDistrictMap.Make("NCX Spaceport / Morro Rock", ""); }
    if gameDistrict == t"Districts.Pacifica" { return NCZDistrictMap.Make("Pacifica", ""); }
    if gameDistrict == t"Districts.Coastview" { return NCZDistrictMap.Make("Pacifica", "Coastview"); }
    if gameDistrict == t"Districts.WestWindEstate" { return NCZDistrictMap.Make("Pacifica", "West Wind Estate"); }
    if gameDistrict == t"Districts.SantoDomingo" { return NCZDistrictMap.Make("Santo Domingo", ""); }
    if gameDistrict == t"Districts.Arroyo" { return NCZDistrictMap.Make("Santo Domingo", "Arroyo"); }
    if gameDistrict == t"Districts.RanchoCoronado" { return NCZDistrictMap.Make("Santo Domingo", "Rancho Coronado"); }
    if gameDistrict == t"Districts.Watson" { return NCZDistrictMap.Make("Watson", ""); }
    if gameDistrict == t"Districts.ArasakaWaterfront" { return NCZDistrictMap.Make("Watson", "Arasaka Waterfront"); }
    if gameDistrict == t"Districts.Kabuki" { return NCZDistrictMap.Make("Watson", "Kabuki"); }
    if gameDistrict == t"Districts.LittleChina" { return NCZDistrictMap.Make("Watson", "Little China"); }
    if gameDistrict == t"Districts.Northside" { return NCZDistrictMap.Make("Watson", "Northside Industrial District"); }
    if gameDistrict == t"Districts.Westbrook" { return NCZDistrictMap.Make("Westbrook", ""); }
    if gameDistrict == t"Districts.CharterHill" { return NCZDistrictMap.Make("Westbrook", "Charter Hill"); }
    if gameDistrict == t"Districts.JapanTown" { return NCZDistrictMap.Make("Westbrook", "Japantown"); }
    if gameDistrict == t"Districts.NorthOaks" { return NCZDistrictMap.Make("Westbrook", "North Oak"); }
    return null;
  }

  // The 9 API districts, A-Z. Includes districts with no locations yet.
  public static func AllDistricts() -> array<String> {
    let out: array<String>;
    ArrayPush(out, "Badlands");
    ArrayPush(out, "City Center");
    ArrayPush(out, "Dogtown");
    ArrayPush(out, "Heywood");
    ArrayPush(out, "NCX Spaceport / Morro Rock");
    ArrayPush(out, "Pacifica");
    ArrayPush(out, "Santo Domingo");
    ArrayPush(out, "Watson");
    ArrayPush(out, "Westbrook");
    return out;
  }

  // The subdistricts of `district`, A-Z (27 in total). Empty for a district with none
  // (Dogtown, NCX Spaceport / Morro Rock) and for an unknown district.
  public static func SubdistrictsOf(district: String) -> array<String> {
    let out: array<String>;
    if UnicodeStringEqual(district, "Badlands") {
      ArrayPush(out, "Biotechnica Flats");
      ArrayPush(out, "Jackson Plains");
      ArrayPush(out, "Laguna Bend");
      ArrayPush(out, "North Sunrise Oil Field");
      ArrayPush(out, "Rattlesnake Creek");
      ArrayPush(out, "Red Peaks");
      ArrayPush(out, "Rocky Ridge");
      ArrayPush(out, "Sierra Sonora");
      ArrayPush(out, "SoCal Border Crossing");
      ArrayPush(out, "Vasquez Pass");
      return out;
    }
    if UnicodeStringEqual(district, "City Center") {
      ArrayPush(out, "Corpo Plaza");
      ArrayPush(out, "Downtown");
      return out;
    }
    if UnicodeStringEqual(district, "Heywood") {
      ArrayPush(out, "The Glen");
      ArrayPush(out, "Vista Del Rey");
      ArrayPush(out, "Wellsprings");
      return out;
    }
    if UnicodeStringEqual(district, "Pacifica") {
      ArrayPush(out, "Coastview");
      ArrayPush(out, "West Wind Estate");
      return out;
    }
    if UnicodeStringEqual(district, "Santo Domingo") {
      ArrayPush(out, "Arroyo");
      ArrayPush(out, "Rancho Coronado");
      return out;
    }
    if UnicodeStringEqual(district, "Watson") {
      ArrayPush(out, "Arasaka Waterfront");
      ArrayPush(out, "Kabuki");
      ArrayPush(out, "Little China");
      ArrayPush(out, "Northside Industrial District");
      return out;
    }
    if UnicodeStringEqual(district, "Westbrook") {
      ArrayPush(out, "Charter Hill");
      ArrayPush(out, "Japantown");
      ArrayPush(out, "North Oak");
      ArrayPush(out, "North Oak Casino");
      return out;
    }
    return out;
  }

  // The game district record(s) whose LocalizedName() names this area, for LocalizeArea().
  // TWO ids means the API's name is a composite of the game's, joined in this order.
  //
  // EMPTY IS AN ANSWER, not a miss: the game has no record for this area, so the caller
  // supplies the name itself. That covers 1 of the 36 areas here, and any
  // subdistrict the registry publishes after this build.
  public static func RecordIdsFor(district: String, subdistrict: String) -> array<TweakDBID> {
    let out: array<TweakDBID>;
    if UnicodeStringEqual(district, "Badlands") && UnicodeStringEqual(subdistrict, "") { ArrayPush(out, t"Districts.Badlands"); return out; }
    if UnicodeStringEqual(district, "Badlands") && UnicodeStringEqual(subdistrict, "Biotechnica Flats") { ArrayPush(out, t"Districts.BiotechnicaFlats"); return out; }
    if UnicodeStringEqual(district, "Badlands") && UnicodeStringEqual(subdistrict, "Jackson Plains") { ArrayPush(out, t"Districts.JacksonPlains"); return out; }
    if UnicodeStringEqual(district, "Badlands") && UnicodeStringEqual(subdistrict, "Laguna Bend") { ArrayPush(out, t"Districts.LagunaBend"); return out; }
    if UnicodeStringEqual(district, "Badlands") && UnicodeStringEqual(subdistrict, "North Sunrise Oil Field") { ArrayPush(out, t"Districts.NorthSunriseOilField"); return out; }
    if UnicodeStringEqual(district, "Badlands") && UnicodeStringEqual(subdistrict, "Rattlesnake Creek") { ArrayPush(out, t"Districts.RattlesnakeCreek"); return out; }
    if UnicodeStringEqual(district, "Badlands") && UnicodeStringEqual(subdistrict, "Red Peaks") { ArrayPush(out, t"Districts.RedPeaks"); return out; }
    if UnicodeStringEqual(district, "Badlands") && UnicodeStringEqual(subdistrict, "Rocky Ridge") { ArrayPush(out, t"Districts.RockyRidge"); return out; }
    if UnicodeStringEqual(district, "Badlands") && UnicodeStringEqual(subdistrict, "Sierra Sonora") { ArrayPush(out, t"Districts.SierraSonora"); return out; }
    if UnicodeStringEqual(district, "Badlands") && UnicodeStringEqual(subdistrict, "SoCal Border Crossing") { ArrayPush(out, t"Districts.SoCalBorderCrossing"); return out; }
    if UnicodeStringEqual(district, "Badlands") && UnicodeStringEqual(subdistrict, "Vasquez Pass") { ArrayPush(out, t"Districts.VasquezPass"); return out; }
    if UnicodeStringEqual(district, "City Center") && UnicodeStringEqual(subdistrict, "") { ArrayPush(out, t"Districts.CityCenter"); return out; }
    if UnicodeStringEqual(district, "City Center") && UnicodeStringEqual(subdistrict, "Corpo Plaza") { ArrayPush(out, t"Districts.CorpoPlaza"); return out; }
    if UnicodeStringEqual(district, "City Center") && UnicodeStringEqual(subdistrict, "Downtown") { ArrayPush(out, t"Districts.Downtown"); return out; }
    if UnicodeStringEqual(district, "Dogtown") && UnicodeStringEqual(subdistrict, "") { ArrayPush(out, t"Districts.Dogtown"); return out; }
    if UnicodeStringEqual(district, "Heywood") && UnicodeStringEqual(subdistrict, "") { ArrayPush(out, t"Districts.Heywood"); return out; }
    if UnicodeStringEqual(district, "Heywood") && UnicodeStringEqual(subdistrict, "The Glen") { ArrayPush(out, t"Districts.Glen"); return out; }
    if UnicodeStringEqual(district, "Heywood") && UnicodeStringEqual(subdistrict, "Vista Del Rey") { ArrayPush(out, t"Districts.VistaDelRey"); return out; }
    if UnicodeStringEqual(district, "Heywood") && UnicodeStringEqual(subdistrict, "Wellsprings") { ArrayPush(out, t"Districts.Wellsprings"); return out; }
    if UnicodeStringEqual(district, "NCX Spaceport / Morro Rock") && UnicodeStringEqual(subdistrict, "") { ArrayPush(out, t"Districts.NCSpaceport"); ArrayPush(out, t"Districts.MorroRock"); return out; }
    if UnicodeStringEqual(district, "Pacifica") && UnicodeStringEqual(subdistrict, "") { ArrayPush(out, t"Districts.Pacifica"); return out; }
    if UnicodeStringEqual(district, "Pacifica") && UnicodeStringEqual(subdistrict, "Coastview") { ArrayPush(out, t"Districts.Coastview"); return out; }
    if UnicodeStringEqual(district, "Pacifica") && UnicodeStringEqual(subdistrict, "West Wind Estate") { ArrayPush(out, t"Districts.WestWindEstate"); return out; }
    if UnicodeStringEqual(district, "Santo Domingo") && UnicodeStringEqual(subdistrict, "") { ArrayPush(out, t"Districts.SantoDomingo"); return out; }
    if UnicodeStringEqual(district, "Santo Domingo") && UnicodeStringEqual(subdistrict, "Arroyo") { ArrayPush(out, t"Districts.Arroyo"); return out; }
    if UnicodeStringEqual(district, "Santo Domingo") && UnicodeStringEqual(subdistrict, "Rancho Coronado") { ArrayPush(out, t"Districts.RanchoCoronado"); return out; }
    if UnicodeStringEqual(district, "Watson") && UnicodeStringEqual(subdistrict, "") { ArrayPush(out, t"Districts.Watson"); return out; }
    if UnicodeStringEqual(district, "Watson") && UnicodeStringEqual(subdistrict, "Arasaka Waterfront") { ArrayPush(out, t"Districts.ArasakaWaterfront"); return out; }
    if UnicodeStringEqual(district, "Watson") && UnicodeStringEqual(subdistrict, "Kabuki") { ArrayPush(out, t"Districts.Kabuki"); return out; }
    if UnicodeStringEqual(district, "Watson") && UnicodeStringEqual(subdistrict, "Little China") { ArrayPush(out, t"Districts.LittleChina"); return out; }
    if UnicodeStringEqual(district, "Watson") && UnicodeStringEqual(subdistrict, "Northside Industrial District") { ArrayPush(out, t"Districts.Northside"); return out; }
    if UnicodeStringEqual(district, "Westbrook") && UnicodeStringEqual(subdistrict, "") { ArrayPush(out, t"Districts.Westbrook"); return out; }
    if UnicodeStringEqual(district, "Westbrook") && UnicodeStringEqual(subdistrict, "Charter Hill") { ArrayPush(out, t"Districts.CharterHill"); return out; }
    if UnicodeStringEqual(district, "Westbrook") && UnicodeStringEqual(subdistrict, "Japantown") { ArrayPush(out, t"Districts.JapanTown"); return out; }
    if UnicodeStringEqual(district, "Westbrook") && UnicodeStringEqual(subdistrict, "North Oak") { ArrayPush(out, t"Districts.NorthOaks"); return out; }
    return out;
  }

  private static func Make(district: String, subdistrict: String) -> ref<NCZDistrictName> {
    let r = new NCZDistrictName();
    r.district = district;
    r.subdistrict = subdistrict;
    return r;
  }
}
