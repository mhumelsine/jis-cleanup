using System.Text;

namespace JisCleanup.Activities;

public class ApplyChangesActivity(TableChange[] changes) : IActivity
{
    public void Build(StringBuilder builder)
    {
        builder.AppendLine(LogEmitter.LogCase("Starting cleanup for case", "CLEANUP"));
        
        foreach (var change in changes)
        {
            builder.AppendLine(change.BeforeSnapshot());
            builder.AppendLine(change.Apply());
            builder.AppendLine(change.AfterSnapshot());
            builder.AppendLine(change.LogOperation());
        }
        
        builder.AppendLine(LogEmitter.LogCase("Completed cleanup for case", "CLEANUP"));

        builder.AppendLine(
            """
                     UPDATE
                         JISREM.CLEANUP_CASE_QUEUE
                     SET
                         status = 'PROCESSED'
                     WHERE
                         cleanup_id = :CLEANUP_ID
                         AND case_id = v_case_id;

             """);
    }
}