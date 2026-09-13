using System.Text;

namespace JisCleanup.Activities;

public class CaseLoopActivity(Cleanup cleanup) : IActivity
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

            CURSOR c_cases IS
                SELECT
                    case_id,
                    spn_id
                FROM
                    JISREM.CLEANUP_CASE_QUEUE
                WHERE
                    cleanup_id = __CLEANUP_ID__
                    AND status = 'QUEUED'
                ORDER BY
                    case_id;
                
            """);
        
        cleanup.Declarations.BuildTypes(builder);

        builder.AppendLine(
            """
            BEGIN
            FOR r_case IN c_cases
            LOOP
                DECLARE
                    v_case_id JISREM.CLEANUP_CASE_QUEUE.case_id%TYPE := r_case.case_id;
                    v_spn_id JISREM.CLEANUP_CASE_QUEUE.spn_id%TYPE := r_case.spn_id;
                    v_is_valid PLS_INTEGER := 0;
                    v_validation_error VARCHAR2(512) := NULL;
                    v_count PLS_INTEGER := 0;
                    v_error_message VARCHAR2(512);

            """);
        
        cleanup.Declarations.BuildVariables(builder);
        
        builder.AppendLine(
            """
                BEGIN
                    SAVEPOINT case_start;
                    
            """);
    }
}