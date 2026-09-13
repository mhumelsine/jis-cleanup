using System.Text;

namespace JisCleanup.Activities;

public class InitializeCleanupActivity(CleanupMetadata metadata) : IActivity
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
                 WHERE cleanup_name='{metadata.Name}';
                 
                 IF v_existing>0 THEN 
                      RAISE_APPLICATION_ERROR(-20002,'Cleanup [{metadata.Name}] already exists'); 
                 END IF;
                 
                 
                 INSERT INTO JISREM.CLEANUP(cleanup_id,cleanup_name,description,requested_by,status)
                 VALUES(__CLEANUP_ID__,'{metadata.Name}','{metadata.Description}','{metadata.RequestedBy}','CREATED');

             """);

        foreach (var charge in metadata.Charges)
        {
            builder.AppendLine(
                $"""
                 INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
                 VALUES(__CLEANUP_ID__, '{charge.CjisCaseNumber}', '{charge.ChargeId}', '{charge.CjisSpn}', 'QUEUED');

                 """);
        }
        
        builder.AppendLine(LogEmitter.Log($"Cleanup [{metadata.Name}] started", "INITIALIZATION"));
        builder.AppendLine(LogEmitter.Log($"[{metadata.Charges.Count}] case(s) will be affected","INITIALIZATION"));

        builder.AppendLine(
            """
            COMMIT;
            END;
            /

            """);
    }
}