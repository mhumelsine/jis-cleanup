using System.Text;
using JisCleanup.Validations;

namespace JisCleanup.Activities;

public class ExecuteValidationsActivity(IValidation[] validations) : IActivity
{
    public void Build(StringBuilder builder)
    {
        builder.AppendLine(
            $"""
              DECLARE
                  v_case_id JISREM.CLEANUP_CASE_QUEUE.case_id%TYPE;
                  v_is_valid PLS_INTEGER := 0;
                  v_validation_error VARCHAR2(512) := NULL;
                  v_count PLS_INTEGER := 0;

                  CURSOR c_cases IS
                      SELECT
                          case_id
                      FROM
                          JISREM.CLEANUP_CASE_QUEUE
                      WHERE
                          cleanup_id = :CLEANUP_ID
                          AND status = 'QUEUED'
                      ORDER BY
                          case_id;

              BEGIN

                  FOR r_case IN c_cases
                  LOOP
                      v_case_id := r_case.case_id;
                      v_is_valid := 0;
                      v_validation_error := ''; 
                      v_count := 0;

             """);
        
        foreach (var validation in validations)
        {
            builder.AppendLine(validation.Validation());
            builder.AppendLine(CheckValidation(validation.GetType().Name));
        }
        
        builder.AppendLine(
            """
                    UPDATE JISREM.CLEANUP_CASE_QUEUE
                    SET status = 'VALIDATED',
                    message = 'All validations passed'
                    WHERE cleanup_id = :CLEANUP_ID
                    AND case_id = v_case_id;
             
                 END LOOP;
             END;
             /

             """);
        
    }

    protected string CheckValidation(string stepName)
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