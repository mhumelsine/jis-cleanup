using JisCleanup;
using JisCleanup.Cleanups;

var cleanup = new Cleanup_02_InmateCleanup();
var inputFilePath = Path.Combine(PathHelper.GetCleanupPath(), $"Cleanup_02_Inmate_Changes.csv");
var writer = new CleanupWriter();
var loader = new CsvChargeLoader(inputFilePath);

cleanup.Build(writer, loader);

Console.WriteLine("Build Success");