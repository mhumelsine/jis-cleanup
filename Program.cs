using JisCleanup;
using JisCleanup.Cleanups;

var cleanup = new Cleanup_01_GroceryStoreRun();
var inputFilePath = Path.Combine(PathHelper.GetCleanupPath(), $"{cleanup.GetType().Name}.csv");
var writer = new CleanupWriter();
var loader = new CsvChargeLoader(inputFilePath);

cleanup.Build(writer, loader);

Console.WriteLine("Build Success");