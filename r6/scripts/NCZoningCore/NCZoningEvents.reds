// ======================================================================================
// Mod Name: NCZoningCore
// File: NCZoningEvents.reds
// Author: Spuddeh
// Description: NCZoningDataEvent - the payload carried by the three data lifecycle
//              events. A CallbackSystemEvent subclass so it is consumable from BOTH
//              redscript and CET Lua through Codeware's CallbackSystem.
// Mod Version: 0.1.0 (Pre-release)
// Credits: psiberx (Codeware CallbackSystem)
// ======================================================================================

module NCZoning.Data

// One payload class, dispatched (in M4) under the three frozen PUBLIC string names:
//   NCZoning-DataReady      - store is populated and queryable (from cache or network)
//   NCZoning-DataRefreshed  - a network fetch replaced the store with newer data
//   NCZoning-DataError      - a fetch failed after retries; Reason() holds a code
// Consumers subscribe by the literal name, e.g. (reds)
//   GameInstance.GetCallbackSystem().RegisterCallback(n"NCZoning-DataReady", this, n"OnReady");
// or (CET Lua)
//   Game.GetCallbackSystem():RegisterCallback('NCZoning-DataReady', target, 'OnReady')
public class NCZoningDataEvent extends CallbackSystemEvent {
  private let datasetVersion: String;
  private let count: Int32;
  private let reason: String;

  public func DatasetVersion() -> String { return this.datasetVersion; }
  public func Count() -> Int32 { return this.count; }
  public func Reason() -> String { return this.reason; }  // populated on DataError only

  public static func Create(datasetVersion: String, count: Int32, reason: String) -> ref<NCZoningDataEvent> {
    let e = new NCZoningDataEvent();
    e.datasetVersion = datasetVersion;
    e.count = count;
    e.reason = reason;
    return e;
  }
}
