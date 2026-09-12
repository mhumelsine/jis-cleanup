using System.Text;

namespace JisCleanup.Validations;

public interface IValidation
{
    void Validation(StringBuilder builder);

    void Declares(BlockDeclarations declarations);
}

public static class ValidationDefaults
{
    public const string
        CurrentCaseId = "v_case_id",
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
    public void Validation(StringBuilder builder)
    {
        builder.AppendLine(Collect());
        builder.AppendLine(Reset());
        builder.AppendLine(Check());
    }

    protected abstract string Collect();
    protected abstract string Check();

    public abstract void Declares(BlockDeclarations declarations);

    private string Reset()
        => $"""
            v_is_valid := 1;
            v_validation_error := NULL;

            """;

    protected string ExactlyOne(string errorMessage)
        => $"""
            IF v_count <> 1 THEN
                v_is_valid := 0;
                v_validation_error := '{errorMessage}';
            END IF;

            """;

    protected string ExactlyZero(string errorMessage)
        => $"""
             IF v_count <> 0 THEN
                 v_is_valid := 0;
                 v_validation_error := '{errorMessage}';
             END IF;

             """;
    
    protected string NotZero(string errorMessage)
        => $"""
            IF v_count = 0 THEN
                v_is_valid := 0;
                v_validation_error := '{errorMessage}';
            END IF;

            """;
}