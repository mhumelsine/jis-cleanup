namespace JisCleanup.Validations;

public sealed class ArrestProvenanceValidation : IValidation
{
    public string Validation()
        => """
            SELECT COUNT(*) INTO v_count FROM JISJDW.ARREST a
            WHERE (EXISTS
            (
                SELECT 1 FROM JISJDW.CUSTODY_STATUS cs
                WHERE cs.arrest_id = a.arrest_id AND EXISTS
            (
                SELECT 1
                FROM JISJDW.CHARGE ch
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = ch.case_defendant_id
                WHERE ch.charge_id = cs.charge_id
                  AND cd.case_id = v_case_id
            )
            )
            OR EXISTS
            (
                SELECT 1 FROM JISJDW.CJIS_DOCKET d
                WHERE d.arrest_id = a.arrest_id AND EXISTS
            (
                SELECT 1
                FROM JISJDW.CHARGE ch
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = ch.case_defendant_id
                WHERE ch.charge_id = d.charge_id
                  AND cd.case_id = v_case_id
            )
            )
            OR EXISTS
            (
                SELECT 1 FROM JISJDW.FIRST_APPEARANCE fa
                WHERE fa.arrest_id = a.arrest_id AND EXISTS
            (
                SELECT 1
                FROM JISJDW.CASE_DEFENDANT cd
                WHERE cd.case_defendant_id = fa.case_defendant_id
                  AND cd.case_id = v_case_id
            )
            ))
            AND (NVL(UPPER(TRIM(a.create_user_id)),'~') NOT IN ('JISJDW','PNX2JIS','SYSTEMA')
             OR (a.update_user_id IS NOT NULL AND UPPER(TRIM(a.update_user_id)) NOT IN ('JISJDW','PNX2JIS','SYSTEMA')));

            v_is_valid := 1;
            v_validation_error := NULL;

            IF v_count > 0 THEN
                v_is_valid := 0;
                v_validation_error := 'Candidate ARREST has human provenance';
            END IF;
            """;
}
