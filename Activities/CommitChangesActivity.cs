using System.Text;

namespace JisCleanup.Activities;

public class CommitChangesActivity : IActivity
{
    public void Build(StringBuilder builder)
    {
        builder.AppendLine(
            """
            BEGIN
             IF :WHAT_IF = 0 THEN
                UPDATE JISREM.CLEANUP 
                SET 
                    status='COMPLETED'
                WHERE cleanup_id=:CLEANUP_ID;
                
                COMMIT;
                
                JISREM.LOG
                (
                    p_cleanup_id => :CLEANUP_ID,
                    p_step_name  => 'TRANSACTION',
                    p_message    => 'Cleanup transaction committed'
                );
                
             ELSE
                ROLLBACK;
                
                JISREM.LOG
                (
                    p_cleanup_id => :CLEANUP_ID,
                    p_step_name  => 'TRANSACTION',
                    p_message    => 'WHAT-IF was true transaction rolled back'
                );
             END IF;
            END;
            /
            
            EXIT SUCCESS
            
            """);
    }
}