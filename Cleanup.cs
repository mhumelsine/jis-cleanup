using System.Text;
using JisCleanup.Activities;
using JisCleanup.Validations;

namespace JisCleanup;

public class Cleanup
{
    private const int PartitionSize = 100;

    public CleanupMetadata Metadata { get; init; }
    public TableChange[] Changes { get; protected init; }
    public IValidation[] Validations { get; protected init; }
    public BlockDeclarations Declarations { get; } = new();

    public void Build<TRecord>(CleanupWriter writer, ILoader<TRecord> loader)
        where TRecord : Charge
    {
        foreach (var partition in Partition(loader))
        {
            CleanupWriter.Write(partition.OutputFileName, Compile(partition));
            Console.WriteLine($"Emitted: {partition.OutputFileName}");
        }
    }

    private List<CleanupBatch<TRecord>> Partition<TRecord>(ILoader<TRecord> loader)
        => loader.Load()
            .Chunk(PartitionSize)
            .Select((x, index) => new CleanupBatch<TRecord>
            {
                OutputFileName = $"{Metadata.Name}_Run{Metadata.RunNumber}_Partition{index + 1}.sql",
                Items = x.ToHashSet(), //Ensure unique by properties
                Metadata = Metadata
            })
            .ToList();

    private string Compile<TRecord>(CleanupBatch<TRecord> batch)
        where TRecord : Charge
    {
        var builder = new StringBuilder();

        new CreateLoggingInfrastructureActivity().Build(builder);
        new LoggingProcedureActivity().Build(builder);
        new EnsureSnapshotTableExistActivity(Changes).Build(builder);
        new InitializeCleanupActivity<TRecord>(batch).Build(builder);
        new ReportCleanupAgentsRegistered(Changes).Build(builder);
        new BeginTransactionActivity().Build(builder);

        foreach (var charge in batch.Items)
        {
            var validateActivity = new ValidationsActivity(charge, Validations);
            var changeActivity = new ApplyChangesActivity(charge, Changes);

            new ChargeBlock(charge, validateActivity, changeActivity).Build(builder);
        }

        new CommitChangesActivity().Build(builder);

        return ResolvePlaceholders(builder);
    }

    private static string ResolvePlaceholders(StringBuilder builder)
        => builder
            .Replace("__CLEANUP_ID__", $"'{Guid.NewGuid().ToString()}'")
            .Replace("__WHAT_IF__", "0")
            .ToString();
}