namespace JisCleanup.Validations;

public sealed class RootProvenanceValidation : IValidation
{
    public string Validation()
        => """
            SELECT COUNT(*) INTO v_count FROM
            (
             SELECT c.create_user_id, c.update_user_id FROM JISJDW.CJIS_CASE c WHERE c.case_id=v_case_id
             UNION ALL SELECT cd.create_user_id, cd.update_user_id FROM JISJDW.CASE_DEFENDANT cd WHERE cd.case_id=v_case_id
             UNION ALL SELECT ch.create_user_id, ch.update_user_id FROM JISJDW.CHARGE ch WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CASE_DEFENDANT cd
                WHERE cd.case_defendant_id = ch.case_defendant_id
                  AND cd.case_id = v_case_id
            )
             UNION ALL SELECT d.create_user_id, d.update_user_id FROM JISJDW.CJIS_DOCKET d WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CHARGE ch
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = ch.case_defendant_id
                WHERE ch.charge_id = d.charge_id
                  AND cd.case_id = v_case_id
            )
            ) u
            WHERE NVL(UPPER(TRIM(u.create_user_id)),'~') NOT IN ('JISJDW','PNX2JIS','SYSTEMA')
            OR (u.update_user_id IS NOT NULL AND UPPER(TRIM(u.update_user_id)) NOT IN ('JISJDW','PNX2JIS','SYSTEMA'));

            v_is_valid := 1;
            v_validation_error := NULL;

            IF v_count > 0 THEN
                v_is_valid := 0;
                v_validation_error := 'Root, charge, or docket row has human provenance';
            END IF;
            """;
}
