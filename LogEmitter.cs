namespace JisCleanup;

public class LogEmitter
{
    public static string Log(string message, string stepName)
        => $"""
            JISREM.LOG
            (
                p_cleanup_id => :CLEANUP_ID,
                p_step_name  => '{stepName}',
                p_message    => '{message}'
            );

            """;
    
    public static string LogCase(string message, string stepName)
        => $"""
            JISREM.LOG
            (
                p_cleanup_id => :CLEANUP_ID,
                p_case_id    => v_case_id,
                p_step_name  => '{stepName}',
                p_message    => '{message}'
            );
            
            """;
    
    public static string LogCaseValidationFailed(string message, string stepName)
        => $"""
            JISREM.LOG
            (
                p_cleanup_id => :CLEANUP_ID,
                p_case_id    => v_case_id,
                p_step_name  => '{stepName}',
                p_message    => 'Error: ' || v_validation_error
            );
            
            """;
}