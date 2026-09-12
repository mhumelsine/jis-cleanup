namespace JisCleanup.Validations;

public sealed class ChargeEvidenceValidation : IValidation
{
    public string Validation()
        => """
            SELECT COUNT(*) INTO v_count FROM JISJDW.CHARGE ch
            WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CASE_DEFENDANT cd
                WHERE cd.case_defendant_id = ch.case_defendant_id
                  AND cd.case_id = v_case_id
            )
            AND NOT EXISTS (SELECT 1 FROM JISJDW.V_PNX2JIS_BAD_DKT b WHERE b.charge_id = ch.charge_id);

            v_is_valid := 1;
            v_validation_error := NULL;

            IF v_count > 0 THEN
                v_is_valid := 0;
                v_validation_error := 'One or more charges have no V_PNX2JIS_BAD_DKT evidence';
            END IF;
            """;
}
