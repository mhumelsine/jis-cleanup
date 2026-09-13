namespace JisCleanup;

public class LogEmitter
{
    public static string Log(string message, string stepName)
        => $"""
            JISREM.LOG
            (
                p_cleanup_id => __CLEANUP_ID__,
                p_step_name  => '{stepName}',
                p_message    => '{message}'
            );

            """;
    
    public static string LogCharge(string message, string stepName, string chargeId)
        => $"""
            JISREM.LOG
            (
                p_cleanup_id => __CLEANUP_ID__,
                p_charge_id    => '{chargeId}',
                p_step_name  => '{stepName}',
                p_message    => '{message}'
            );
            
            """;
    
    public static string LogCaseValidationFailed(string stepName, int chargeId)
        => $"""
            JISREM.LOG
            (
                p_cleanup_id => __CLEANUP_ID__,
                p_charge_id    => '{chargeId}',
                p_step_name  => '{stepName}',
                p_message    => 'Error: ' || v_validation_error
            );
            
            """;
}