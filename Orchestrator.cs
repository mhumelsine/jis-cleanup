using System.Text;
using JisCleanup.Activities;
using JisCleanup.Validations;

namespace JisCleanup;

public class Cleanup
{
    public CleanupMetadata Metadata { get; set; }
    public TableChange[] Changes { get; set; }
    public IValidation[] Validations { get; set; }

    public BlockDeclarations Declarations { get; set; } = new();
}

public class Orchestrator
{
    public void Build(Cleanup cleanup)
    {
        var builder = new StringBuilder();
        
        //add global declarations
        cleanup.Declarations.AddVariable("v_count", "NUMBER");
        
        new CreateLoggingInfrastructureActivity().Build(builder);
        new LoggingProcedureActivity().Build(builder);
        new EnsureSnapshotTableExistActivity(cleanup.Changes).Build(builder);
        new InitializeCleanupActivity(cleanup.Metadata).Build(builder);
        new ReportCleanupAgentsRegistered(cleanup.Changes).Build(builder);
        new BeginTransactionActivity().Build(builder);
        new ExecuteValidationsActivity(cleanup.Validations).Build(builder);
        new ApplyChangesActivity(cleanup.Changes).Build(builder);
        new CommitChangesActivity().Build(builder);
        
        File.WriteAllText(cleanup.Metadata.OutputfileName, builder.ToString());
    }
}