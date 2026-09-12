namespace JisCleanup.Validations;

public sealed class SatelliteProvenanceValidation : IValidation
{
    public string Validation()
        => """
            SELECT COUNT(*) INTO v_count FROM
            (
            SELECT x.create_user_id,x.update_user_id FROM JISJDW.CUSTODY_STATUS x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CHARGE ch
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = ch.case_defendant_id
                WHERE ch.charge_id = x.charge_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT x.create_user_id,x.update_user_id FROM JISJDW.RELEASE_BOND x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CHARGE ch
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = ch.case_defendant_id
                WHERE ch.charge_id = x.charge_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT x.create_user_id,x.update_user_id FROM JISJDW.FIRST_APPEARANCE x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CASE_DEFENDANT cd
                WHERE cd.case_defendant_id = x.case_defendant_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT x.create_user_id,x.update_user_id FROM JISJDW.FA_CHARGE x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CHARGE ch
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = ch.case_defendant_id
                WHERE ch.charge_id = x.charge_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT x.create_user_id,x.update_user_id FROM JISJDW.COURT_CALENDAR x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CASE_DEFENDANT cd
                WHERE cd.case_defendant_id = x.case_defendant_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT x.create_user_id,x.update_user_id FROM JISJDW.CHARGE_JAIL_INFO x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CHARGE ch
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = ch.case_defendant_id
                WHERE ch.charge_id = x.charge_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT x.create_user_id,x.update_user_id FROM JISJDW.ARREST x WHERE (EXISTS
            (
                SELECT 1 FROM JISJDW.CUSTODY_STATUS cs
                WHERE cs.arrest_id = x.arrest_id AND EXISTS
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
                WHERE d.arrest_id = x.arrest_id AND EXISTS
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
                WHERE fa.arrest_id = x.arrest_id AND EXISTS
            (
                SELECT 1
                FROM JISJDW.CASE_DEFENDANT cd
                WHERE cd.case_defendant_id = fa.case_defendant_id
                  AND cd.case_id = v_case_id
            )
            ))
            UNION ALL
            SELECT x.create_user_id,x.update_user_id FROM JISJDW.CASE_RELATED_PERSON x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CASE_DEFENDANT cd
                WHERE cd.case_defendant_id = x.case_defendant_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT i.create_user_id,i.update_user_id FROM JISJDW.INMATE i WHERE EXISTS (SELECT 1 FROM JISJDW.ARREST a WHERE a.inmate_id=i.inmate_id AND (EXISTS
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
            )))
            UNION ALL
            SELECT ja.create_user_id,ja.update_user_id FROM JISJDW.JAIL_ACTIVITY ja WHERE EXISTS (SELECT 1 FROM JISJDW.ARREST a WHERE a.inmate_id=ja.inmate_id AND (EXISTS
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
            )))
            ) u
            WHERE NVL(UPPER(TRIM(u.create_user_id)),'~') NOT IN ('JISJDW','PNX2JIS','SYSTEMA')
            OR (u.update_user_id IS NOT NULL AND UPPER(TRIM(u.update_user_id)) NOT IN ('JISJDW','PNX2JIS','SYSTEMA'));

            v_is_valid := 1;
            v_validation_error := NULL;

            IF v_count > 0 THEN
                v_is_valid := 0;
                v_validation_error := 'Custody, hearing, bond, arrest, inmate, or jail row has human provenance';
            END IF;
            """;
}
