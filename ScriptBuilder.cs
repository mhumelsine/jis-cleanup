using System.Reflection;

namespace JisCleanup;

public static class ScriptBuilder
{
    public static void Build(string cleanupName, string timestamp)
    {
        ArgumentNullException.ThrowIfNull(cleanupName);

        var cleanupType = Type.GetType($"JisCleanup.Cleanups.Cleanup_{cleanupName}");

        if (cleanupType == null)
            throw new InvalidOperationException($"Could not resolve type for cleanup name '{cleanupName}'");
        
        var instance = Activator.CreateInstance(cleanupType);

        if (instance == null)
            throw new InvalidOperationException($"Could not create instance of type '{cleanupType.FullName}'");

        var cleanup = (CleanupBase)instance;
        var manualCleanupAttribute = cleanupType.GetCustomAttribute<ManualCleanupAttribute>();
        
        Console.WriteLine($"Using:\t\t{cleanupType.FullName}");

        string? dataFilePath;
        
        if (manualCleanupAttribute is not null)
        {
            dataFilePath = Path.Combine(PathHelper.GetCleanupPath(cleanupName), manualCleanupAttribute.InputFileName);

            if (!File.Exists(dataFilePath))
            {
                throw new FileNotFoundException($"Expected data file '{dataFilePath}' was not found");
            }
        }
        else
        {
            var queryFilePath = Path.Combine(PathHelper.GetCleanupPath(cleanupName), $"query.sql");
            dataFilePath = Path.Combine(PathHelper.GetCleanupPath(cleanupName), $"{timestamp}_data.csv");
            
            Console.WriteLine($"Query file:\t\t{queryFilePath}");
            
            var extractor = new OracleFacade();
            extractor.Extract(queryFilePath, dataFilePath);
        }
        
        Console.WriteLine($"Data file:\t\t{dataFilePath}");
        var loader = new CsvChargeLoader(dataFilePath);
        
        cleanup.Build(loader, timestamp, PathHelper.GetCleanupPath(cleanupName));

        Console.WriteLine("Build Success");
    }
}