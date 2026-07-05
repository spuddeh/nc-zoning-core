# Examples

Consumer integration samples land here in M5:

- A redscript soft-dependency example, guarded with
  `@if(ModuleExists("NCZoning.Api"))` and gated at runtime on `ApiVersion()`.
- A CET Lua bridge that subscribes to `NCZoning-DataReady` through
  `Game.GetCallbackSystem():RegisterCallback(...)`.
