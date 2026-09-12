namespace JisCleanup.Validations;

public sealed class AdvancedCaseGraphValidation : IValidation
{
    public string Validation()
        => """
            SELECT COUNT(*) INTO v_count FROM (
            SELECT 1 FROM JISJDW.ARRAIGNMENT x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CASE_DEFENDANT cd
                WHERE cd.case_defendant_id = x.case_defendant_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT 1 FROM JISJDW.FINAL_DISPOSITION x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CASE_DEFENDANT cd
                WHERE cd.case_defendant_id = x.case_defendant_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT 1 FROM JISJDW.COURT_CONDITIONS x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CASE_DEFENDANT cd
                WHERE cd.case_defendant_id = x.case_defendant_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT 1 FROM JISJDW.HEALTH_CONDITION_CASE x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CASE_DEFENDANT cd
                WHERE cd.case_defendant_id = x.case_defendant_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT 1 FROM JISJDW.JURY_NON_JURY_TRIAL x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CASE_DEFENDANT cd
                WHERE cd.case_defendant_id = x.case_defendant_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT 1 FROM JISJDW.MOTION_HEARING x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CASE_DEFENDANT cd
                WHERE cd.case_defendant_id = x.case_defendant_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT 1 FROM JISJDW.PLEA_HEARING x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CASE_DEFENDANT cd
                WHERE cd.case_defendant_id = x.case_defendant_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT 1 FROM JISJDW.PRE_TRIAL_CASE_MANAGEMENT x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CASE_DEFENDANT cd
                WHERE cd.case_defendant_id = x.case_defendant_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT 1 FROM JISJDW.VOP_HEARING x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CASE_DEFENDANT cd
                WHERE cd.case_defendant_id = x.case_defendant_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT 1 FROM JISJDW.VICTIM_CASE_DEFENDANT x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CASE_DEFENDANT cd
                WHERE cd.case_defendant_id = x.case_defendant_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT 1 FROM JISJDW.WARRANT x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CASE_DEFENDANT cd
                WHERE cd.case_defendant_id = x.case_defendant_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT 1 FROM JISJDW.MENTAL_HEALTH x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CASE_DEFENDANT cd
                WHERE cd.case_defendant_id = x.case_defendant_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT 1 FROM JISJDW.ATICKET_CASEDEF x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CASE_DEFENDANT cd
                WHERE cd.case_defendant_id = x.case_defendant_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT 1 FROM JISJDW.ARRAIGNMENT_CHARGE x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CHARGE ch
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = ch.case_defendant_id
                WHERE ch.charge_id = x.charge_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT 1 FROM JISJDW.RELEASE x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CHARGE ch
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = ch.case_defendant_id
                WHERE ch.charge_id = x.charge_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT 1 FROM JISJDW.MENTAL_HEALTH_CHARGE x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CHARGE ch
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = ch.case_defendant_id
                WHERE ch.charge_id = x.charge_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT 1 FROM JISJDW.ICE_INMATE_LOG x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CHARGE ch
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = ch.case_defendant_id
                WHERE ch.charge_id = x.charge_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT 1 FROM JISJDW.FINAL_DISPOSITION_CHARGE x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CHARGE ch
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = ch.case_defendant_id
                WHERE ch.charge_id = x.charge_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT 1 FROM JISJDW.JURY_NON_JURY_TRIAL_CHARGE x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CHARGE ch
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = ch.case_defendant_id
                WHERE ch.charge_id = x.charge_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT 1 FROM JISJDW.MOTION_HEARING_CHARGE x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CHARGE ch
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = ch.case_defendant_id
                WHERE ch.charge_id = x.charge_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT 1 FROM JISJDW.PLEA_HEARING_CHARGE x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CHARGE ch
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = ch.case_defendant_id
                WHERE ch.charge_id = x.charge_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT 1 FROM JISJDW.PRE_TRIAL_CASE_MGMT_CHARGE x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CHARGE ch
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = ch.case_defendant_id
                WHERE ch.charge_id = x.charge_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT 1 FROM JISJDW.VOP_HEARING_CHARGE x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CHARGE ch
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = ch.case_defendant_id
                WHERE ch.charge_id = x.charge_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT 1 FROM JISJDW.WARRANT_CHARGE x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CHARGE ch
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = ch.case_defendant_id
                WHERE ch.charge_id = x.charge_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT 1 FROM JISJDW.VEHICLE x WHERE x.case_id=v_case_id
            UNION ALL
            SELECT 1 FROM JISJDW.VICTIM x WHERE x.case_id=v_case_id
            UNION ALL
            SELECT 1 FROM JISJDW.CASE_CERTIFICATION_INFO x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CHARGE ch
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = ch.case_defendant_id
                WHERE ch.charge_id = x.old_charge_id
                  AND cd.case_id = v_case_id
            ) OR EXISTS
            (
                SELECT 1
                FROM JISJDW.CHARGE ch
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = ch.case_defendant_id
                WHERE ch.charge_id = x.new_charge_id
                  AND cd.case_id = v_case_id
            )
            UNION ALL
            SELECT 1 FROM JISJDW.CHARGE x WHERE EXISTS
            (
                SELECT 1
                FROM JISJDW.CASE_DEFENDANT cd
                WHERE cd.case_defendant_id = x.case_defendant_id
                  AND cd.case_id = v_case_id
            ) AND x.warrant_id IS NOT NULL
            );

            v_is_valid := 1;
            v_validation_error := NULL;

            IF v_count > 0 THEN
                v_is_valid := 0;
                v_validation_error := 'Advanced court, warrant, expunge, health, vehicle, or certification data exists';
            END IF;
            """;
}
