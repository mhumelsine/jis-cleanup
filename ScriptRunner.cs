namespace JisCleanup;

public static class ScriptRunner
{
    public static void Run(string cleanupName, string timestamp)
    {
        ArgumentNullException.ThrowIfNull(cleanupName);
        ArgumentNullException.ThrowIfNull(timestamp);

        var scriptPath = Path.Combine(PathHelper.GetCleanupPath(cleanupName), "scripts", timestamp);

        Console.WriteLine(scriptPath);
        
        if (!Directory.Exists(scriptPath)) throw new ArgumentException($"Cleanup '{cleanupName}/{timestamp}' was not found");

        var db = new OracleFacade();
        
        var files = Directory
            .EnumerateFiles(scriptPath, "*.sql", SearchOption.TopDirectoryOnly)
            .OrderBy(File.GetLastWriteTimeUtc);
        
        foreach (var file in files)
        {
            try
            {
                Console.Write($"Executing: {Path.GetFileName(file)}  \t");
                db.ExecuteCommandFromFile(Path.Combine(scriptPath, file));
                Console.WriteLine("Success");
            }
            catch (Exception ex)
            {
                Console.WriteLine("Failed");
                Console.WriteLine($"Exception running file: {Path.GetFileName(file)}");
                Console.WriteLine(ex.Message);
                Console.WriteLine(ex.StackTrace);
            }
        }
    }
    
}