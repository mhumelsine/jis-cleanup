using JisCleanup;
using JisCleanup.Cleanups;

var cleanup = new JudicialOrderCleanup();
var inputFilePath = Path.Combine(PathHelper.GetCleanupPath(), $"2024CF1550A2_Order.csv");
var writer = new CleanupWriter();
var loader = new CsvChargeLoader(inputFilePath);

cleanup.Build(writer, loader);

Console.WriteLine("Build Success");