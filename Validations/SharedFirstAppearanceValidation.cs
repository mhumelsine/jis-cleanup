namespace JisCleanup.Validations;

public sealed class SharedFirstAppearanceValidation : IValidation
{
    public string Validation()
        => """
            SELECT COUNT(*) INTO v_count FROM JISJDW.FA_CHARGE fc
            WHERE EXISTS (SELECT 1 FROM JISJDW.FIRST_APPEARANCE fa WHERE fa.first_appearance_id = fc.first_appearance_id AND EXISTS
            (
                SELECT 1
                FROM JISJDW.CASE_DEFENDANT cd
                WHERE cd.case_defendant_id = fa.case_defendant_id
                  AND cd.case_id = v_case_id
            ))
            AND NOT EXISTS (SELECT 1 FROM JISJDW.CHARGE ch WHERE ch.charge_id = fc.charge_id AND EXISTS
            (
                SELECT 1
                FROM JISJDW.CASE_DEFENDANT cd
                WHERE cd.case_defendant_id = ch.case_defendant_id
                  AND cd.case_id = v_case_id
            ));

            v_is_valid := 1;
            v_validation_error := NULL;

            IF v_count > 0 THEN
                v_is_valid := 0;
                v_validation_error := 'FIRST_APPEARANCE is shared with a charge outside the ghost case';
            END IF;
            """;
}
