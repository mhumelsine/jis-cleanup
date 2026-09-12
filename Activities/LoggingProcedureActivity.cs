using System.Text;

namespace JisCleanup.Activities;

public class LoggingProcedureActivity : IActivity
{
    public void Build(StringBuilder builder)
    {
        builder.AppendLine(
            """
            CREATE OR REPLACE PROCEDURE JISREM.LOG
            (
                p_cleanup_id    IN JISREM.CLEANUP_LOG.cleanup_id%TYPE,
                p_case_id       IN JISREM.CLEANUP_LOG.case_id%TYPE       DEFAULT NULL,
                p_step_name     IN JISREM.CLEANUP_LOG.step_name%TYPE     DEFAULT NULL,
                p_message       IN JISREM.CLEANUP_LOG.message%TYPE       DEFAULT NULL,
                p_affected_rows IN JISREM.CLEANUP_LOG.affected_rows%TYPE DEFAULT NULL
            )
            IS
                PRAGMA AUTONOMOUS_TRANSACTION;
            BEGIN
                INSERT INTO JISREM.CLEANUP_LOG
                (
                    cleanup_id,
                    case_id,
                    log_sequence,
                    logged_at,
                    step_name,
                    message,
                    affected_rows
                )
                VALUES
                (
                    p_cleanup_id,
                    p_case_id,
                    JISREM.CLEANUP_LOG_SEQ.NEXTVAL,
                    SYSDATE,
                    p_step_name,
                    p_message,
                    p_affected_rows
                );
            
                COMMIT;
            EXCEPTION
                WHEN OTHERS THEN
                    ROLLBACK;
                    RAISE;
            END LOG;
            /
            
            """);
    }
}