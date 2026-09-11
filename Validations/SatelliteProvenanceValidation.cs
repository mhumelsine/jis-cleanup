namespace JisCleanup.Validations;

public sealed class SatelliteProvenanceValidation : IValidation
{
    public string Validation()
        => $"""
            SELECT COUNT(*) INTO v_count
                FROM
                (
                    SELECT create_user_id,update_user_id FROM JISJDW.CUSTODY_STATUS
                     WHERE charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids))
                    UNION ALL
                    SELECT create_user_id,update_user_id FROM JISJDW.RELEASE_BOND
                     WHERE bond_id IN (SELECT COLUMN_VALUE FROM TABLE(v_bond_ids))
                    UNION ALL
                    SELECT create_user_id,update_user_id FROM JISJDW.FIRST_APPEARANCE
                     WHERE first_appearance_id IN (SELECT COLUMN_VALUE FROM TABLE(v_fa_ids))
                    UNION ALL
                    SELECT create_user_id,update_user_id FROM JISJDW.FA_CHARGE
                     WHERE charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids))
                    UNION ALL
                    SELECT create_user_id,update_user_id FROM JISJDW.COURT_CALENDAR
                     WHERE court_calendar_id IN (SELECT COLUMN_VALUE FROM TABLE(v_cal_ids))
                    UNION ALL
                    SELECT create_user_id,update_user_id FROM JISJDW.CHARGE_JAIL_INFO
                     WHERE charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids))
                    UNION ALL
                    SELECT create_user_id,update_user_id FROM JISJDW.ARREST
                     WHERE arrest_id IN (SELECT COLUMN_VALUE FROM TABLE(v_arrest_ids))
                    UNION ALL
                    SELECT create_user_id,update_user_id FROM JISJDW.INMATE
                     WHERE inmate_id IN (SELECT COLUMN_VALUE FROM TABLE(v_inmate_ids))
                    UNION ALL
                    SELECT create_user_id,update_user_id FROM JISJDW.JAIL_ACTIVITY
                     WHERE inmate_id IN (SELECT COLUMN_VALUE FROM TABLE(v_inmate_ids))
                    UNION ALL
                    SELECT create_user_id,update_user_id FROM JISJDW.CASE_RELATED_PERSON
                     WHERE case_defendant_id=v_case_defendant_id
                ) u
                WHERE NVL(UPPER(TRIM(u.create_user_id)),'~') NOT IN ('JISJDW','PNX2JIS','SYSTEMA')
                   OR (u.update_user_id IS NOT NULL
                       AND UPPER(TRIM(u.update_user_id)) NOT IN ('JISJDW','PNX2JIS','SYSTEMA'));

            {IValidation.Check("Custody, hearing, bond, arrest, inmate, or jail row has human provenance")}
            """;
}
