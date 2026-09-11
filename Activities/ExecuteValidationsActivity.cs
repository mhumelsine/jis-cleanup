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
                  v_case_id JISJDW.Z__CLEANUP_CASE_QUEUE.case_id%TYPE;
                  v_is_valid PLS_INTEGER := 0;
                  v_validation_error := NULL;

                  CURSOR c_cases IS
                      SELECT
                          case_id
                      FROM
                          JISJDW.Z__CLEANUP_CASE_QUEUE
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

             """);
        
        foreach (var validation in validations)
        {
            builder.AppendLine(validation.Validation());
            builder.AppendLine(CheckValidation());
        }
        
        builder.AppendLine(
            """
                 END LOOP;
             END;
             /

             """);
        
    }

    protected string CheckValidation()
        => $"""
            UPDATE
                JISJDW.Z__CLEANUP_CASE_QUEUE
            SET
                status = CASE WHEN v_is_valid = 1
                     THEN 'VALIDATED'
                     ELSE 'VALIDATION_FAILED'
                     END,
                message = v_validation_error
            WHERE
                cleanup_id = :CLEANUP_ID
                AND case_id = v_case_id;

            IF v_is_valid <> 1 THEN
                {LogEmitter.LogCaseValidationFailed("Validation failed")}
                CONTINUE;
            END IF;

            """;
}