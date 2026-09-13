using JisCleanup;
using JisCleanup.Cleanups;

var cleanup = new Cleanup_01_GroceryStoreRun();
var orchestrator = new Orchestrator();

orchestrator.Build(cleanup);

Console.WriteLine("Build Success");