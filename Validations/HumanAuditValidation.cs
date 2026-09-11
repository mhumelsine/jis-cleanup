namespace JisCleanup.Validations;

public sealed class HumanAuditValidation : IValidation
{
    public string Validation()
        => $"""
            SELECT MIN(create_date_time) INTO v_bad_start
                FROM JISJDW.CJIS_DOCKET
                WHERE cjis_docket_id IN (SELECT COLUMN_VALUE FROM TABLE(v_docket_ids));
            
                -- Root and charge rows must have machine provenance.
                SELECT COUNT(*) INTO v_count
                FROM
                (
                    SELECT c.create_user_id,c.update_user_id FROM JISJDW.CJIS_CASE c WHERE c.case_id=v_case_id
                    UNION ALL
                    SELECT cd.create_user_id,cd.update_user_id FROM JISJDW.CASE_DEFENDANT cd WHERE cd.case_defendant_id=v_case_defendant_id
                    UNION ALL
                    SELECT create_user_id,update_user_id FROM JISJDW.CHARGE
                     WHERE charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids))
                    UNION ALL
                    SELECT create_user_id,update_user_id FROM JISJDW.CJIS_DOCKET
                     WHERE cjis_docket_id IN (SELECT COLUMN_VALUE FROM TABLE(v_docket_ids))
                ) u
                WHERE NVL(UPPER(TRIM(u.create_user_id)),'~') NOT IN ('JISJDW','PNX2JIS','SYSTEMA')
                   OR (u.update_user_id IS NOT NULL
                       AND UPPER(TRIM(u.update_user_id)) NOT IN ('JISJDW','PNX2JIS','SYSTEMA'));
            
                -- Any human audit on this exact graph after incident creation blocks deletion.
                SELECT COUNT(*) INTO v_count
                FROM JISJDW.AUDIT_TRAIL a
                WHERE a.cjis_spn=in_spn
                  AND (a.cjis_case_number=v_caseno OR a.cjis_case_number LIKE v_caseno||'%')
                  AND a.activity_date_time>=v_bad_start
                  AND NVL(UPPER(TRIM(a.activity_user_id)),'~') NOT IN ('JISJDW','PNX2JIS','SYSTEMA');

            {IValidation.Check("Human AUDIT_TRAIL activity exists on the case graph")}
            """;
}
