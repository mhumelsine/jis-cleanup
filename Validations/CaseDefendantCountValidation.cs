namespace JisCleanup.Validations;

public sealed class CaseDefendantCountValidation : IValidation
{
    public string Validation()
        => """
            SELECT COUNT(*) INTO v_count FROM JISJDW.CASE_DEFENDANT cd WHERE cd.case_id = v_case_id;

            v_is_valid := 1;
            v_validation_error := NULL;

            IF v_count <> 1 THEN
                v_is_valid := 0;
                v_validation_error := 'Expected exactly one CASE_DEFENDANT';
            END IF;
            """;
}
