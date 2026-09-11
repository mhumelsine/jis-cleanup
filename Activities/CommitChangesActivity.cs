using System.Text;

namespace JisCleanup.Activities;

public class CommitChangesActivity : IActivity
{
    public void Build(StringBuilder builder)
    {
        builder.AppendLine(
            """
            BEGIN
             IF TO_NUMBER('&&WHAT_IF')=1 THEN
                ROLLBACK;
                DBMS_OUTPUT.PUT_LINE('WHAT-IF completed. All changes rolled back.');
             ELSE
                 UPDATE JISJDW.Z__CLEANUP 
                 SET 
                     status='COMPLETED',
                     executed_date=SYSDATE 
                 WHERE cleanup_id=:CLEANUP_ID;
                 COMMIT;
                 DBMS_OUTPUT.PUT_LINE('Cleanup committed.');
             END IF;
            END;
            /
            UNDEFINE WHAT_IF
            EXIT SUCCESS
            
            """);
    }
}