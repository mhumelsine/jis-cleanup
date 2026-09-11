using System.Text;

namespace JisCleanup.Activities;

public class InitializeCleanupActivity(CleanupMetadata metadata) : IActivity
{
    public void Build(StringBuilder builder)
    {
        builder.AppendLine(
            $"""
             WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
             SET SERVEROUTPUT ON
             SET VERIFY OFF

             DEFINE WHAT_IF='&1'
             VARIABLE CLEANUP_ID NUMBER

             DECLARE
                 v_existing NUMBER; 
                 v_what_if NUMBER;
             BEGIN
                 v_what_if:=TO_NUMBER('&&WHAT_IF');
                 
                 IF v_what_if NOT IN (0,1) THEN 
                      RAISE_APPLICATION_ERROR(-20001,'WHAT_IF must be 0 or 1'); END IF;
                 
                 SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
                 
                 SELECT COUNT(*) 
                 INTO v_existing 
                 FROM JISJDW.Z__CLEANUP 
                 WHERE cleanup_name='{metadata.Name}';
                 
                 IF v_existing>0 THEN 
                      RAISE_APPLICATION_ERROR(-20002,'Cleanup [{metadata.Name}] already exists'); 
                 END IF;
                 
                 SELECT JISJDW.Z__CLEANUP_SEQ.NEXTVAL 
                 INTO :CLEANUP_ID 
                 FROM dual;
                 
                 INSERT INTO JISJDW.Z__CLEANUP(cleanup_id,cleanup_name,description,requested_by,status)
                 VALUES(:CLEANUP_ID,'{metadata.Name}','{metadata.Description}','{metadata.RequestedBy}','CREATED');

             """);

        foreach (var caseId in metadata.CaseIds)
        {
            builder.AppendLine(
                $"  INSERT INTO JISJDW.Z__CLEANUP_CASE_QUEUE(cleanup_id,case_id. status) VALUES(:CLEANUP_ID,{caseId}, 'QUEUED');");
        }
        
        builder.AppendLine(LogEmitter.Log($"Cleanup [{metadata.Name}] started"));
        builder.AppendLine(LogEmitter.Log($"[{metadata.CaseIds.Length}] cased will be affected"));

        builder.AppendLine(
            """
            END;
            /

            """);
    }
}