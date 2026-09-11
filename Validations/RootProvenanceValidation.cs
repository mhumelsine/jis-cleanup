namespace JisCleanup.Validations;

public sealed class RootProvenanceValidation : IValidation
{
    public string Validation()
        => $"""
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

            {IValidation.Check("Root, charge, or docket row has human provenance")}
            """;
}
