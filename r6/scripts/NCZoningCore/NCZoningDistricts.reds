// ======================================================================================
// Mod Name: NCZoningCore
// File: NCZoningDistricts.reds
// Author: Spuddeh
// Description: GENERATED - do not hand-edit. Static (Layer 1) map from the game's district
//              TweakDBID (from District.GetDistrictID()) to the NC Zoning API district /
//              subdistrict strings, for the editorial cases where the two vocabularies
//              differ. Regenerate + verify with tools/districts/build-district-map.py.
// Mod Version: 0.1.0 (Pre-release)
// ======================================================================================

module NCZoning.Api

public class NCZDistrictName {
  public let district: String;
  public let subdistrict: String;   // "" for a top-level district
}

public class NCZDistrictMap {
  // The game's current district TweakDBID -> API district/subdistrict. Returns null when
  // the game district is not directly on the map; the caller walks up the parent chain
  // (Layer 2) and retries. 38 entries, verified against /v1/districts.
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

  private static func Make(district: String, subdistrict: String) -> ref<NCZDistrictName> {
    let r = new NCZDistrictName();
    r.district = district;
    r.subdistrict = subdistrict;
    return r;
  }
}
