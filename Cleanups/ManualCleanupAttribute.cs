namespace JisCleanup;

public class ManualCleanupAttribute(string InputFileName) : Attribute
{
    public string InputFileName { get; } = InputFileName;
}