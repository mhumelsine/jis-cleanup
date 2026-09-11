using System.Text;

namespace JisCleanup.Activities;

public class ApplyChangesActivity(TableChange[] changes) : IActivity
{
    public void Build(StringBuilder builder)
    {
        builder.AppendLine(
            """
             DECLARE

                 v_case_id JISJDW.Z__CLEANUP_CASE_QUEUE.case_id%TYPE;

                 CURSOR c_cases IS
                     SELECT
                         case_id
                     FROM
                         JISJDW.Z__CLEANUP_CASE_QUEUE
                     WHERE
                         cleanup_id = :CLEANUP_ID
                         AND status = 'VALIDATED'
                     ORDER BY
                         case_id;

             BEGIN

                 FOR r_case IN c_cases
                 LOOP
                     v_case_id := r_case.case_id;
                     
            """);
        
        foreach (var change in changes)
        {
            builder.AppendLine(LogEmitter.LogCase("Starting cleanup for case"));
            builder.AppendLine(change.BeforeSnapshot());
            builder.AppendLine(change.Apply());
            builder.AppendLine(change.AfterSnapshot());
            builder.AppendLine(change.LogOperation());
            builder.AppendLine(LogEmitter.LogCase("Completed cleanup for case"));
        }

        builder.AppendLine(
            """
                     UPDATE
                         JISJDW.Z__CLEANUP_CASE_QUEUE
                     SET
                         status = 'PROCESSED'
                     WHERE
                         cleanup_id = :CLEANUP_ID
                         AND case_id = v_case_id;

                 END LOOP;

             END;
             /

             """);
    }
}