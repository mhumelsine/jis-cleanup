using JisCleanup;
using JisCleanup.Cleanups;

var cleanup = new Cleanup_01_DeleteMachineCreatedRecords();
var orchestrator = new Orchestrator();

orchestrator.Build(cleanup);

Console.WriteLine("Build Success");