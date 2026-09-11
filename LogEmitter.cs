namespace JisCleanup;

public class LogEmitter
{
    public static string Log(string message)
        => $"""
            INSERT INTO JISJDW.Z__CLEANUP_LOG
            (
                cleanup_id,
                log_sequence,
                message
            )
            VALUES
            (
                :cleanup_id,
                JISJDW.Z__CLEANUP_LOG_SEQ.NEXTVAL,
                '{message}'
            );
            """;
    
    public static string LogCase(string message)
        => $"""
            INSERT INTO JISJDW.Z__CLEANUP_LOG
            (
                cleanup_id,
                case_id,
                log_sequence,
                message
            )
            VALUES
            (
                :cleanup_id,
                v_case_id,
                JISJDW.Z__CLEANUP_LOG_SEQ.NEXTVAL,
                '{message}'
            );
            """;
    
    public static string LogCaseValidationFailed(string message)
        => $"""
            INSERT INTO JISJDW.Z__CLEANUP_LOG
            (
                cleanup_id,
                case_id,
                log_sequence,
                message
            )
            VALUES
            (
                :cleanup_id,
                v_case_id,
                JISJDW.Z__CLEANUP_LOG_SEQ.NEXTVAL,
                '{message} Error: ' || v_validation_error
            );
            """;
}