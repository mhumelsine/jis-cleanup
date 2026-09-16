namespace JisCleanup;

public static class PathHelper
{
    public static string GetCleanupPath(string cleanupName)
    {
        var relativePath = Path.Combine("..", "..", "..", "Cleanups", cleanupName);
        
        var baseDirectory = AppDomain.CurrentDomain.BaseDirectory;
        var root = Path.GetFullPath(Path.Combine(baseDirectory, relativePath));
        
        if (!Directory.Exists(root))
        {
            throw new DirectoryNotFoundException($"{root} was not found using relative path '{relativePath}'");
        }

        return root;
    }
}