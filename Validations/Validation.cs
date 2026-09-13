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
        BadDataStartDate = "",
        OnlySustemCreatedOrChanged =
            """
            AND (NVL(UPPER(TRIM(create_user_id)),'~') NOT IN ('JISJDW','PNX2JIS','SYSTEMA')
            OR (update_user_id IS NOT NULL 
                    AND UPPER(TRIM(update_user_id)) NOT IN ('JISJDW','PNX2JIS','SYSTEMA')));
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
    
    protected static string CheckValidation(string stepName, string chargeId)
        => $"""
            IF v_is_valid <> 1 THEN
                {LogEmitter.LogCaseValidationFailed(stepName, chargeId)}
               
               UPDATE
                    JISREM.CLEANUP_CASE_QUEUE
                SET
                    status = 'VALIDATION_FAILED',
                    message = v_validation_error
                WHERE
                    cleanup_id = :CLEANUP_ID
                    AND charge_id = '{chargeId}';
               
                RETURN;
            END IF;

            """;
}