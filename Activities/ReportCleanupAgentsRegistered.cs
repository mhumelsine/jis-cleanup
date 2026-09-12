using System.Text;

namespace JisCleanup.Activities;

public class ReportCleanupAgentsRegistered(TableChange[] changes) : IActivity
{
    public void Build(StringBuilder builder)
    {
        builder.AppendLine(
            """
             BEGIN
             """);
        
        builder.AppendLine(LogEmitter.Log($"[{changes.Length}] changes will be applied", "INITIALIZATION"));
        
        foreach (var change in changes)
        {
            builder.AppendLine(LogEmitter.Log($"Cleanup agent registered: {change}", "INITIALIZATION"));
        }

        builder.AppendLine(
            """
            END;
            /

            """);
    }
}