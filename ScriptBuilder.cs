namespace JisCleanup;

public static class ScriptBuilder
{
    public static void Build(string cleanupName, string timestamp)
    {
        ArgumentNullException.ThrowIfNull(cleanupName);

        var cleanupType = Type.GetType($"JisCleanup.Cleanups.Cleanup_{cleanupName}");

        if (cleanupType == null)
            throw new InvalidOperationException($"Could not resolve type for cleanup name '{cleanupName}'");
        
        var queryFilePath = Path.Combine(PathHelper.GetCleanupPath(cleanupName), $"query.sql");
        var dataFilePath = Path.Combine(PathHelper.GetCleanupPath(cleanupName), $"{timestamp}_data.csv");

        Console.WriteLine($"Using:\t\t{cleanupType.FullName}");
        Console.WriteLine($"Query file:\t\t{queryFilePath}");
        Console.WriteLine($"Query file:\t\t{dataFilePath}");

        var instance = Activator.CreateInstance(cleanupType);

        if (instance == null)
            throw new InvalidOperationException($"Could not create instance of type '{cleanupType.FullName}'");

        var cleanup = (CleanupBase)instance;

        var extractor = new OracleFacade();
        var loader = new CsvChargeLoader(dataFilePath);

        extractor.Extract(queryFilePath, dataFilePath);
        cleanup.Build(loader, timestamp, PathHelper.GetCleanupPath(cleanupName));

        Console.WriteLine("Build Success");
    }
}