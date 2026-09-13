namespace JisCleanup;

public record CleanupMetadata
{
    public string OutputfileName => $"{AppContext.BaseDirectory}/Cleanups/{Name}.sql";
    public string InputfileName => $"{AppContext.BaseDirectory}/Cleanups/{Name}.csv";
    public required string Name { get; init; }
    public required string Description { get; init; }
    public required string RequestedBy { get; init; }
    public HashSet<Charge> Charges { get; init; } = [];

    public void Load()
    {
        var file = new FileInfo(InputfileName);

        if (!file.Exists) throw new FileNotFoundException($"Input file '{InputfileName}' was not found");

        foreach (var line in File.ReadAllLines(file.FullName).Skip(1))
        {
            var segment = line.Split(',');

            //TODO:  New new file format
            if (segment.Length != 4) throw new FileLoadException($"File contains invalid data at: '{line}'");

            var charge = new Charge
            {
                ChargeId = segment[0],
                CjisChargeNumber = segment[1],
                Spn = int.Parse(segment[2]),
                BondAmount = segment[3],
                //Location = segment[4],
                //Status = segment[5]
            };

            Charges.Add(charge);
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