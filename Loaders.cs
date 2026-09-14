namespace JisCleanup;

public interface ILoader<out TRecord>
{
    IEnumerable<TRecord> Load();
}

public class CsvChargeLoader(string filePath) : ILoader<Charge>
{
    public IEnumerable<Charge> Load()
    {
        if (!File.Exists(filePath)) throw new FileNotFoundException($"Input file '{filePath}' was not found");

        foreach (var line in File.ReadAllLines(filePath).Skip(1))
        {
            var segment = line.Split(',');

            if (segment.Length != 7) throw new FileLoadException($"File contains invalid data at: '{line}'");

            yield return new Charge
            {
                CjisSpn = int.Parse(segment[0]),
                CjisCaseNumber = segment[1],
                CaseDefendantId = int.Parse(segment[2]),
                ChargeId = int.Parse(segment[3]),
                Status = segment[4],
                Location = segment[5],
                BondAmount = segment[6]
            };
        }
    }
}