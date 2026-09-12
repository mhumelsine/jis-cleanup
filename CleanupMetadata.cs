namespace JisCleanup;

public record CleanupMetadata
{
    public string OutputfileName => $"{AppContext.BaseDirectory}/Cleanups/{Name}.sql";
    public string InputfileName => $"{AppContext.BaseDirectory}/Cleanups/{Name}.csv";
    public required string Name { get; init; }
    public required string Description { get; init; }
    public required string RequestedBy { get; init; }
    public HashSet<Case> Cases { get; init; } = [];

    public void Load()
    {
        var file = new FileInfo(InputfileName);

        if (!file.Exists) throw new FileNotFoundException($"Input file '{InputfileName}' was not found");

        foreach (var line in File.ReadAllLines(file.FullName).Skip(1))
        {
            var segment = line.Split(',');

            if (segment.Length != 4) throw new FileLoadException($"File contains invalid data at: '{line}'");

            var cjisCase = new Case(segment[0], segment[1], segment[2], segment[3]);

            Cases.Add(cjisCase);
        }
    }

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