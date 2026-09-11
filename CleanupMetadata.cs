namespace JisCleanup;

public record CleanupMetadata
{
    public string CleanupConfigurationFileName => $"{AppContext.BaseDirectory}/Cleanups/{Name}.yaml";
    public string OutputfileName => $"{AppContext.BaseDirectory}/Cleanups/{Name}.sql";
    public required string Name { get; init; }
    public required string Description { get; init; }
    public required string RequestedBy { get; init; }
    public required int[] CaseIds { get; init; } = [];

    // public CleanupMetadata()
    // {
    //     if (string.IsNullOrWhiteSpace(Name)) throw new InvalidOperationException("Cleanup name is missing");
    //     if (string.IsNullOrWhiteSpace(Description)) throw new InvalidOperationException("Cleanup description is missing");
    //     if (string.IsNullOrWhiteSpace(RequestedBy)) throw new InvalidOperationException("Requested by is missing");
    //     
    //     if (CaseIds.Length == 0) throw new InvalidOperationException("Cleanup must have cases");
    //     
    //     CleanupConfigurationFileName = $"{AppContext.BaseDirectory}/Cleanups/{Name}.yaml";
    //     OutputfileName = $"{AppContext.BaseDirectory}/Cleanups/{Name}.sql";
    // }
}