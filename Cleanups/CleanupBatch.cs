namespace JisCleanup;

public record CleanupBatch<T>
{
    public required CleanupMetadata Metadata { get; set; }
    public required string OutputFileName { get; set; }
    public required HashSet<T> Items { get; init; }
}