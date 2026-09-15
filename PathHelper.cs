namespace JisCleanup;

public class PathHelper
{
    private static string GetCleanupPath()
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
    
    public static string OutputPath()
    {
        var output = Path.Combine(GetCleanupPath(), "output");

        if (!Directory.Exists(output))
        {
            Directory.CreateDirectory(output);
        }

        return output;
    }
    
    public static string InputPath()
    {
        var input = Path.Combine(GetCleanupPath(), "input");

        if (!Directory.Exists(input))
        {
            throw new DirectoryNotFoundException($"Path: '{input}' was not found");
        }

        return input;
    }


}