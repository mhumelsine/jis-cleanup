namespace JisCleanup.Validations;

public sealed class HumanAuditValidation : IValidation
{
    public string Validation()
        => """
            SELECT COUNT(*) INTO v_count FROM JISJDW.AUDIT_TRAIL a
            WHERE EXISTS
            (
             SELECT 1 FROM JISJDW.CASE_DEFENDANT cd
             WHERE cd.case_id=v_case_id AND cd.cjis_spn=a.cjis_spn
             AND (a.cjis_case_number=cd.cjis_case_number OR a.cjis_case_number LIKE cd.cjis_case_number||'%')
            )
            AND a.activity_date_time >=
            (
             SELECT MIN(d.create_date_time) FROM JISJDW.CJIS_DOCKET d WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CHARGE ch
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = ch.case_defendant_id
                WHERE ch.charge_id = d.charge_id
                  AND cd.case_id = v_case_id
            )
            )
            AND NVL(UPPER(TRIM(a.activity_user_id)),'~') NOT IN ('JISJDW','PNX2JIS','SYSTEMA');

            v_is_valid := 1;
            v_validation_error := NULL;

            IF v_count > 0 THEN
                v_is_valid := 0;
                v_validation_error := 'Human AUDIT_TRAIL activity exists on the case graph';
            END IF;
            """;
}
