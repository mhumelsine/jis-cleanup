using System.Text;

namespace JisCleanup.Activities;

public class EndCaseLoopActivity : IActivity
{
    public void Build(StringBuilder builder)
    {
        builder.AppendLine(
            """
                EXCEPTION
                    WHEN OTHERS THEN
                        v_error_message :=
                        SUBSTR(SQLERRM || ' ' ||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,1,512);
            
                    ROLLBACK TO case_start;
            
                    JISREM.LOG
                    (
                        p_cleanup_id => :CLEANUP_ID,
                        p_charge_id => v_case_id,
                        p_step_name => 'CASE_ERROR',
                        p_message => v_error_message
                    );
            
                    UPDATE JISREM.CLEANUP_CASE_QUEUE
                    SET 
                        status = 'PROCESSING_FAILED',
                        message = v_error_message
                    WHERE cleanup_id = :CLEANUP_ID
                    AND case_id = v_case_id;
                    
                END;
            End LOOP;
            """);
    }
}