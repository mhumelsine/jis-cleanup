using System.Text;

namespace JisCleanup.Validations;

public interface IValidation
{
    void Validation(StringBuilder builder, Charge charge);

    void Declares(BlockDeclarations declarations);
}

public static class ValidationDefaults
{
    public const string
        BadDataStartDate = "AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')",
        OnlySystemCreatedOrChanged =
            """
            AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
            """;
}

public abstract class Validator : IValidation
{
    public void Validation(StringBuilder builder, Charge charge)
    {
        builder.AppendLine("IF v_is_valid = 1 THEN");
        builder.AppendLine(Collect(charge));
        builder.AppendLine(Check());
        builder.AppendLine(CheckValidation(GetType().Name, charge.ChargeId));
        builder.AppendLine("END IF;");
    }

    protected abstract string Collect(Charge charge);
    protected abstract string Check();

    public abstract void Declares(BlockDeclarations declarations);
    

    protected static string ExactlyOne(string errorMessage)
        => $"""
            IF v_count <> 1 THEN
                v_is_valid := 0;
                v_validation_error := '{errorMessage}';
            END IF;

            """;

    protected static string ExactlyZero(string errorMessage)
        => $"""
             IF v_count <> 0 THEN
                 v_is_valid := 0;
                 v_validation_error := '{errorMessage}';
             END IF;

             """;
    
    protected static string NotZero(string errorMessage)
        => $"""
            IF v_count = 0 THEN
                v_is_valid := 0;
                v_validation_error := '{errorMessage}';
            END IF;

            """;
    
    protected static string CheckValidation(string stepName, int chargeId)
        => $"""
            IF v_is_valid <> 1 THEN
                {LogEmitter.LogCaseValidationFailed(stepName, chargeId)}
               
               UPDATE
                    JISREM.CLEANUP_CASE_QUEUE
                SET
                    status = 'VALIDATION_FAILED',
                    message = v_validation_error
                WHERE
                    cleanup_id = __CLEANUP_ID__
                    AND charge_id = {chargeId};
               
                RETURN;
            END IF;

            """;
}