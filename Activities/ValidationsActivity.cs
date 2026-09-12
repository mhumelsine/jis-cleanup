using System.Text;

namespace JisCleanup.Activities;

public class ValidationsActivity(Cleanup cleanup) : IActivity
{
    public void Build(StringBuilder builder)
    { 
        foreach (var validation in cleanup.Validations)
        {
            validation.Validation(builder);
            builder.AppendLine(CheckValidation(validation.GetType().Name));
        }
        
        builder.AppendLine(
            """
                    UPDATE JISREM.CLEANUP_CASE_QUEUE
                    SET status = 'VALIDATED',
                    message = 'All validations passed'
                    WHERE cleanup_id = :CLEANUP_ID
                    AND case_id = v_case_id;

             """);
        
    }

    protected static string CheckValidation(string stepName)
        => $"""
            IF v_is_valid <> 1 THEN
                {LogEmitter.LogCaseValidationFailed("Validation failed", stepName)}
               
               UPDATE
                    JISREM.CLEANUP_CASE_QUEUE
                SET
                    status = 'VALIDATION_FAILED',
                    message = v_validation_error
                WHERE
                    cleanup_id = :CLEANUP_ID
                    AND case_id = v_case_id;
               
                CONTINUE;
            END IF;

            """;
}