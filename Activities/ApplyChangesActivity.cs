using System.Text;

namespace JisCleanup.Activities;

public class ApplyChangesActivity(Charge charge, TableChange[] changes) : IDeclareActivity
{
    public void Build(StringBuilder builder)
    {
        builder.AppendLine(LogEmitter.LogCharge("Starting cleanup for case", "CLEANUP", charge.ChargeId.ToString()));
        
        foreach (var change in changes)
        {
            builder.AppendLine(change.BeforeSnapshot(charge));
            builder.AppendLine(change.ApplyChange(charge));
            builder.AppendLine(change.AfterSnapshot(charge));
            builder.AppendLine(change.LogOperation(charge));
        }
        
        builder.AppendLine(LogEmitter.LogCharge("Completed cleanup for case", "CLEANUP", charge.ChargeId.ToString()));

        builder.AppendLine(
            $"""
                     UPDATE
                         JISREM.CLEANUP_CASE_QUEUE
                     SET
                         status = 'PROCESSED'
                     WHERE
                         cleanup_id = __CLEANUP_ID__
                         AND charge_id = '{charge.ChargeId}';

             """);
    }

    public void BuildDeclares(BlockDeclarations declarations)
    {
        foreach (var change in changes)
        {
            change.AddDeclares(declarations);
        }
    }
}