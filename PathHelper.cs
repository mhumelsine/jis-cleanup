namespace JisCleanup;

public class PathHelper
{
    public static string GetCleanupPath()
    {
        var relativePath = Path.Combine("..", "..", "..", "Cleanups");
        
        var baseDirectory = AppDomain.CurrentDomain.BaseDirectory;
        var root = Path.GetFullPath(Path.Combine(baseDirectory, relativePath));
        
        if (!Directory.Exists(root))
        {
            throw new DirectoryNotFoundException($"{root} was not found using relative path '{relativePath}'");
        }

        return root;
    }
}