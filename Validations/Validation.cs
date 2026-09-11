namespace JisCleanup.Validations;

public interface IValidation
{
    string Validation();
    
    public static string Check(string errorMessage)
        => $"""
            v_is_valid := 1;
            v_validation_error := NULL;

            IF v_count > 0 THEN
                v_is_valid := 0;
                v_validation_error := '{errorMessage}';
            END IF;
            
            """;
}

public static class ValidationDefaults
{
    public const string
        CurrentCaseId = "v_case_id",
        BadDataStartDate = "";
}