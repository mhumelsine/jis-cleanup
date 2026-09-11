namespace JisCleanup.Validations;

public sealed class AdvancedCaseGraphValidation : IValidation
{
    public string Validation()
        => $"""
            SELECT
                    (SELECT COUNT(*) FROM JISJDW.ARRAIGNMENT x WHERE x.case_defendant_id=v_case_defendant_id)+
                    (SELECT COUNT(*) FROM JISJDW.FINAL_DISPOSITION x WHERE x.case_defendant_id=v_case_defendant_id)+
                    (SELECT COUNT(*) FROM JISJDW.COURT_CONDITIONS x WHERE x.case_defendant_id=v_case_defendant_id)+
                    (SELECT COUNT(*) FROM JISJDW.HEALTH_CONDITION_CASE x WHERE x.case_defendant_id=v_case_defendant_id)+
                    (SELECT COUNT(*) FROM JISJDW.JURY_NON_JURY_TRIAL x WHERE x.case_defendant_id=v_case_defendant_id)+
                    (SELECT COUNT(*) FROM JISJDW.MOTION_HEARING x WHERE x.case_defendant_id=v_case_defendant_id)+
                    (SELECT COUNT(*) FROM JISJDW.PLEA_HEARING x WHERE x.case_defendant_id=v_case_defendant_id)+
                    (SELECT COUNT(*) FROM JISJDW.PRE_TRIAL_CASE_MANAGEMENT x WHERE x.case_defendant_id=v_case_defendant_id)+
                    (SELECT COUNT(*) FROM JISJDW.VOP_HEARING x WHERE x.case_defendant_id=v_case_defendant_id)+
                    (SELECT COUNT(*) FROM JISJDW.VEHICLE x WHERE x.case_id=v_case_id)+
                    (SELECT COUNT(*) FROM JISJDW.VICTIM x WHERE x.case_id=v_case_id)+
                    (SELECT COUNT(*) FROM JISJDW.VICTIM_CASE_DEFENDANT x WHERE x.case_defendant_id=v_case_defendant_id)+
                    (SELECT COUNT(*) FROM JISJDW.WARRANT x WHERE x.case_defendant_id=v_case_defendant_id)+
                    (SELECT COUNT(*) FROM JISJDW.MENTAL_HEALTH x WHERE x.case_defendant_id=v_case_defendant_id)+
                    (SELECT COUNT(*) FROM JISJDW.ATICKET_CASEDEF x WHERE x.case_defendant_id=v_case_defendant_id)+
                    (SELECT COUNT(*) FROM JISJDW.CASE_CERTIFICATION_INFO
                      WHERE old_charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids))
                         OR new_charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids)))+
                    (SELECT COUNT(*) FROM JISJDW.ARRAIGNMENT_CHARGE
                      WHERE charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids)))+
                    (SELECT COUNT(*) FROM JISJDW.RELEASE
                      WHERE charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids)))+
                    (SELECT COUNT(*) FROM JISJDW.MENTAL_HEALTH_CHARGE
                      WHERE charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids)))+
                    (SELECT COUNT(*) FROM JISJDW.ICE_INMATE_LOG
                      WHERE charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids)))+
                    (SELECT COUNT(*) FROM JISJDW.FINAL_DISPOSITION_CHARGE
                      WHERE charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids)))+
                    (SELECT COUNT(*) FROM JISJDW.JURY_NON_JURY_TRIAL_CHARGE
                      WHERE charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids)))+
                    (SELECT COUNT(*) FROM JISJDW.MOTION_HEARING_CHARGE
                      WHERE charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids)))+
                    (SELECT COUNT(*) FROM JISJDW.PLEA_HEARING_CHARGE
                      WHERE charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids)))+
                    (SELECT COUNT(*) FROM JISJDW.PRE_TRIAL_CASE_MGMT_CHARGE
                      WHERE charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids)))+
                    (SELECT COUNT(*) FROM JISJDW.VOP_HEARING_CHARGE
                      WHERE charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids)))+
                    (SELECT COUNT(*) FROM JISJDW.WARRANT_CHARGE
                      WHERE charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids)))+
                    (SELECT COUNT(*) FROM JISJDW.CHARGE
                      WHERE charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids)) AND warrant_id IS NOT NULL)
                INTO v_count FROM dual;

            {IValidation.Check("Advanced court, warrant, expunge, health, vehicle, or certification data exists")}
            """;
}
