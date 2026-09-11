using System.Text;
using JisCleanup.Activities;
using JisCleanup.Validations;

namespace JisCleanup;

public class Cleanup2
{
    public CleanupMetadata Metadata { get; set; }
    public TableChange[] Changes { get; set; }
    public IValidation[] Validations { get; set; }
    
}

public class Orchestrator
{
    public void Build(Cleanup2 cleanup)
    {
        var builder = new StringBuilder();
        
        new CreateLoggingInfrastructureActivity().Build(builder);
        new EnsureSnapshotTableExistActivity(cleanup.Changes).Build(builder);
        new InitializeCleanupActivity(cleanup.Metadata).Build(builder);
        new ReportCleanupAgentsRegistered(cleanup.Changes).Build(builder);
        new ExecuteValidationsActivity(cleanup.Validations).Build(builder);
        new ApplyChangesActivity(cleanup.Changes).Build(builder);
        new CommitChangesActivity().Build(builder);
        
        File.WriteAllText(cleanup.Metadata.OutputfileName, builder.ToString());
    }
}