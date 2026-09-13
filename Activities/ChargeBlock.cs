using System.Text;

namespace JisCleanup.Activities;

public class ChargeBlock(Charge charge, IActivity Validate, IActivity Apply) : IActivity
{
    public void Build(StringBuilder builder)
    {
        builder.AppendLine(
            $"""
             /***********************************************************
             ***** CHARGE {charge.ChargeId} CJIS_CASE_NUMBER {charge.CjisCaseNumber}
             ***********************************************************/
             
             DECLARE
                 v_is_valid PLS_INTEGER := 1;
                 v_validation_error VARCHAR2(512) := NULL;
                 v_count PLS_INTEGER := 0;
                 v_error_message VARCHAR2(512);
                 v_docket_ids VARCHAR2(1024);
                 v_inserted_id PLS_INTEGER := 0;
             BEGIN
                SAVEPOINT before_record;
                
             """
        );

        Validate.Build(builder);
        Apply.Build(builder);

        builder.AppendLine(
            $"""
            EXCEPTION
                WHEN OTHERS THEN
                    v_error_message := SUBSTR(SQLERRM, 1, 512);

                    ROLLBACK TO before_record;
                    
                    JISREM.LOG
                    (
                        p_cleanup_id => :CLEANUP_ID,
                        p_charge_id    => '{charge.ChargeId}',
                        p_step_name  => 'EXCEPTION',
                        p_message    => v_error_message
                    );
                    
                    UPDATE JISREM.CLEANUP_CASE_QUEUE
                    SET 
                        status = 'PROCESSING_FAILED',
                        message = v_error_message
                    WHERE cleanup_id = :CLEANUP_ID
                    AND charge_id = '{charge.ChargeId}';
            END;
            /
            
            """
        );
    }
}