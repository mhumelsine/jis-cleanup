using System.Text;

namespace JisCleanup.Activities;

public class InitializeCleanupActivity<TRecord>(CleanupBatch<TRecord> cleanup) : IActivity
    where TRecord : Charge
{
    public void Build(StringBuilder builder)
    {
        builder.AppendLine(
            $"""
             SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
             


             DECLARE
                 v_existing NUMBER; 
             BEGIN
             
                 IF __WHAT_IF__ IS NULL OR __WHAT_IF__ NOT IN (0,1) THEN 
                      RAISE_APPLICATION_ERROR(-20001,'__WHAT_IF__ must be 0 or 1'); END IF;
                 
                 SELECT COUNT(*) 
                 INTO v_existing 
                 FROM JISREM.CLEANUP 
                 WHERE cleanup_name='{cleanup.Metadata.Name}';
                 
                 IF v_existing>0 THEN 
                      RAISE_APPLICATION_ERROR(-20002,'Cleanup [{cleanup.Metadata.Name}] already exists'); 
                 END IF;
                 
                 
                 INSERT INTO JISREM.CLEANUP(cleanup_id,cleanup_name,description,requested_by,status)
                 VALUES(__CLEANUP_ID__,'{cleanup.Metadata.Name}','{cleanup.Metadata.Description}','{cleanup.Metadata.RequestedBy}','CREATED');

             """);

        foreach (var charge in cleanup.Items)
        {
            builder.AppendLine(
                $"""
                 INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
                 VALUES(__CLEANUP_ID__, '{charge.CjisCaseNumber}', '{charge.ChargeId}', '{charge.CjisSpn}', 'QUEUED');

                 """);
        }
        
        builder.AppendLine(LogEmitter.Log($"Cleanup [{cleanup.Metadata.Name}] started", "INITIALIZATION"));
        builder.AppendLine(LogEmitter.Log($"[{cleanup.Items.Count}] case(s) will be affected","INITIALIZATION"));

        builder.AppendLine(
            """
            COMMIT;
            END;
            /

            """);
    }
}