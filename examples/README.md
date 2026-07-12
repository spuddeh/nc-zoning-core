# Examples

Two consumer integration samples. Both are teaching references, not shipped files.

**`RedscriptConsumer.reds`** is a redscript soft-dependency example. Every top-level item is
guarded with `@if(ModuleExists("NCZoning.Api"))`, so it compiles to nothing when NCZoningCore is
absent, and it gates at runtime on `ApiVersion()`. It subscribes to the lifecycle events
(`NCZoning-DataReady` / `-DataRefreshed` / `-DataError`) through Codeware's CallbackSystem.

**`cet_lua_consumer.lua`** is a CET Lua example. Lua does **not** use those CallbackSystem events:
they are dispatched from redscript and are not delivered to Lua listeners. Hook the API's own
methods with CET's `Observe` instead:

```lua
Observe("NCZoningApi", "OnDataReady", function(_, count, datasetVersion, isRefresh)
  -- isRefresh is false on the first load, true on a later network refresh
end)
```

Polling `IsReady()` also works if you prefer it. `docs/consumer-guide.md` covers both paths.
