using System.Text;

namespace JisCleanup.Activities;

public class DeclaresActivity(Cleanup cleanup) : IActivity
{
    public void Build(StringBuilder builder)
    {
        foreach (var validation in cleanup.Validations)
        {
            validation.Declares(cleanup.Declarations);
        }
        
        foreach (var change in cleanup.Changes)
        {
            change.AddDeclares(cleanup.Declarations);
        }
        
        builder.AppendLine(
            """
            DECLARE

            v_case_id JISREM.CLEANUP_CASE_QUEUE.case_id%TYPE;
            v_is_valid PLS_INTEGER := 0;
            v_validation_error VARCHAR2(512) := NULL;
            v_count PLS_INTEGER := 0;
            
            CURSOR c_validate_cases IS
                SELECT
                    case_id
                FROM
                    JISREM.CLEANUP_CASE_QUEUE
                WHERE
                    cleanup_id = __CLEANUP_ID__
                    AND status = 'QUEUED'
                ORDER BY
                    case_id;
                    
            CURSOR c_process_cases IS
                SELECT
                     case_id
                FROM
                    JISREM.CLEANUP_CASE_QUEUE
                WHERE
                    cleanup_id = __CLEANUP_ID__
                    AND status = 'VALIDATED'
                ORDER BY
                    case_id;

            """);
        
        cleanup.Declarations.BuildTypes(builder);
        cleanup.Declarations.BuildVariables(builder);
        
    }
}