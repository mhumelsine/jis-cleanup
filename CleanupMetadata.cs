namespace JisCleanup;

public record CleanupMetadata
{
    public required string Name { get; init; }
    public required string Description { get; init; }
    public required string RequestedBy { get; init; }
    public int RunNumber { get; init; } = 1;

    public static readonly CleanupMetadata None = new()
    {
        Name = "INVALID INVALID",
        Description = "INVALID INVALID",
        RequestedBy = "INVALID INVALID",
        RunNumber = int.MaxValue
    };
}