using System.Text;

namespace JisCleanup.Activities;

public class InitializeCleanupActivity(CleanupMetadata metadata) : IActivity
{
    public void Build(StringBuilder builder)
    {
        builder.AppendLine(
            $"""
             SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
             
             VARIABLE WHAT_IF NUMBER
             VARIABLE CLEANUP_ID NUMBER
             
             EXEC :WHAT_IF := 1

             DECLARE
                 v_existing NUMBER; 
             BEGIN
             
                 IF :WHAT_IF IS NULL OR :WHAT_IF NOT IN (0,1) THEN 
                      RAISE_APPLICATION_ERROR(-20001,'WHAT_IF must be 0 or 1'); END IF;
                 
                 SELECT COUNT(*) 
                 INTO v_existing 
                 FROM JISREM.CLEANUP 
                 WHERE cleanup_name='{metadata.Name}';
                 
                 IF v_existing>0 THEN 
                      RAISE_APPLICATION_ERROR(-20002,'Cleanup [{metadata.Name}] already exists'); 
                 END IF;
                 
                 SELECT JISREM.CLEANUP_SEQ.NEXTVAL 
                 INTO :CLEANUP_ID 
                 FROM dual;
                 
                 INSERT INTO JISREM.CLEANUP(cleanup_id,cleanup_name,description,requested_by,status)
                 VALUES(:CLEANUP_ID,'{metadata.Name}','{metadata.Description}','{metadata.RequestedBy}','CREATED');

             """);

        foreach (var charge in metadata.Charges)
        {
            builder.AppendLine(
                $"""
                 INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
                 VALUES(:CLEANUP_ID, '{charge.CjisCaseNumber}', '{charge.ChargeId}', '{charge.Spn}', 'QUEUED');

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