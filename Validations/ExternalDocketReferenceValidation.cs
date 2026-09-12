namespace JisCleanup.Validations;

public sealed class ExternalDocketReferenceValidation : IValidation
{
    public string Validation()
        => """
            SELECT COUNT(*) INTO v_count FROM JISJDW.CJIS_DOCKET d
            WHERE
            (
             EXISTS (SELECT 1 FROM JISJDW.FIRST_APPEARANCE fa WHERE fa.first_appearance_id=d.first_appearance_id AND EXISTS
            (
                SELECT 1
                FROM JISJDW.CASE_DEFENDANT cd
                WHERE cd.case_defendant_id = fa.case_defendant_id
                  AND cd.case_id = v_case_id
            ))
             OR EXISTS (SELECT 1 FROM JISJDW.COURT_CALENDAR cc WHERE cc.court_calendar_id=d.court_calendar_id AND EXISTS
            (
                SELECT 1
                FROM JISJDW.CASE_DEFENDANT cd
                WHERE cd.case_defendant_id = cc.case_defendant_id
                  AND cd.case_id = v_case_id
            ))
             OR EXISTS (SELECT 1 FROM JISJDW.RELEASE_BOND rb WHERE rb.bond_id=d.bond_id AND EXISTS
            (
                SELECT 1
                FROM JISJDW.CHARGE ch
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = ch.case_defendant_id
                WHERE ch.charge_id = rb.charge_id
                  AND cd.case_id = v_case_id
            ))
            )
            AND NOT (EXISTS
            (
                SELECT 1
                FROM JISJDW.CHARGE ch
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = ch.case_defendant_id
                WHERE ch.charge_id = d.charge_id
                  AND cd.case_id = v_case_id
            ));

            v_is_valid := 1;
            v_validation_error := NULL;

            IF v_count > 0 THEN
                v_is_valid := 0;
                v_validation_error := 'Hearing or bond is referenced by a docket outside the ghost docket set';
            END IF;
            """;
}
