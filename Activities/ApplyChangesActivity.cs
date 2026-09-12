using System.Text;

namespace JisCleanup.Activities;

public class ApplyChangesActivity(TableChange[] changes) : IActivity
{
    public void Build(StringBuilder builder)
    {
        var declares = new BlockDeclarations();

        foreach (var change in changes)
        {
            change.AddDeclares(declares);
        }
        
        builder.AppendLine(
            """
            DECLARE

            v_case_id JISREM.CLEANUP_CASE_QUEUE.case_id%TYPE;
            
            """);
        
        declares.BuildTypes(builder);
        declares.BuildVariables(builder);
        
        builder.AppendLine(
            """
                 CURSOR c_cases IS
                     SELECT
                          case_id
                     FROM
                         JISREM.CLEANUP_CASE_QUEUE
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

                 END LOOP;

             END;
             /

             """);
    }
}