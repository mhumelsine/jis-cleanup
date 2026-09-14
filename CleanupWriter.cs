namespace JisCleanup;

public class CleanupWriter
{
    public static void Write(string fileName, string content)
    {
        var targetFilePath = Path.Combine(PathHelper.GetCleanupPath(), fileName);
        
        File.WriteAllText(targetFilePath, content);
    }
}