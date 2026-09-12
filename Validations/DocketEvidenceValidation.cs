namespace JisCleanup.Validations;

public sealed class DocketEvidenceValidation : IValidation
{
    public string Validation()
        => """
            SELECT COUNT(*) INTO v_count FROM JISJDW.CJIS_DOCKET d
            WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CHARGE ch
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = ch.case_defendant_id
                WHERE ch.charge_id = d.charge_id
                  AND cd.case_id = v_case_id
            )
            AND NOT EXISTS (SELECT 1 FROM JISJDW.V_PNX2JIS_BAD_DKT b WHERE b.cjis_docket_id = d.cjis_docket_id);

            v_is_valid := 1;
            v_validation_error := NULL;

            IF v_count > 0 THEN
                v_is_valid := 0;
                v_validation_error := 'Case contains a docket not present in V_PNX2JIS_BAD_DKT';
            END IF;
            """;
}
