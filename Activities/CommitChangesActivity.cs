using System.Text;

namespace JisCleanup.Activities;

public class CommitChangesActivity : IActivity
{
    public void Build(StringBuilder builder)
    {
        builder.AppendLine(
            """
            BEGIN
             IF __WHAT_IF__ = 0 THEN
                UPDATE JISREM.CLEANUP 
                SET 
                    status='CHARGES_PROCESSED'
                WHERE cleanup_id = __CLEANUP_ID__;
                
                JISREM.LOG
                (
                    p_cleanup_id => __CLEANUP_ID__,
                    p_step_name  => 'TRANSACTION',
                    p_message    => 'All charges processed'
                );
                
             ELSE
                JISREM.LOG
                (
                    p_cleanup_id => __CLEANUP_ID__,
                    p_step_name  => 'TRANSACTION',
                    p_message    => 'WHAT-IF was true all charges rolled back'
                );
             END IF;
            END;
            /
            
            """);
    }
}