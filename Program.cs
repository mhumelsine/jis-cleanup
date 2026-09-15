using JisCleanup;

if (args.Length != 1)
    throw new ArgumentException("Missing positional argument for the cleanup name");

var cleanupName = args[0];
var cleanupType = Type.GetType($"JisCleanup.Cleanups.{cleanupName}");

if (cleanupType == null)
    throw new InvalidOperationException($"Could not resolve type for cleanup name '{cleanupName}'");

var inputFilePath = Path.Combine(PathHelper.InputPath(), $"{cleanupType.Name}.csv");

Console.WriteLine($"Using {cleanupType.FullName}");
Console.WriteLine($"Input file: {inputFilePath}");


var instance = Activator.CreateInstance(cleanupType);

if (instance == null)
    throw new InvalidOperationException($"Could not create instance of type '{cleanupType.FullName}'");

var cleanup = (Cleanup)instance;

var writer = new CleanupWriter();
var loader = new CsvChargeLoader(inputFilePath);

cleanup.Build(writer, loader);

Console.WriteLine("Build Success");