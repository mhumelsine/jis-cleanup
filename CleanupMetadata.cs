namespace JisCleanup;

public record CleanupMetadata
{
    public required string Name { get; init; }
    public required string Description { get; init; }
    public required string RequestedBy { get; init; }
    public int RunNumber { get; set; }

}