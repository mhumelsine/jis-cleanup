namespace JisCleanup.Validations;

public class NoHumanActivityValidation : IValidation
{
    public string Validation()
        => $"""
           SELECT
               COUNT(*)
           INTO
               v_count
           FROM
               JISJDW.AUDIT_TRAIL a
           WHERE
               a.cjis_spn = in_spn
               AND (
                   a.cjis_case_number = {ValidationDefaults.CurrentCaseId}
                   OR a.cjis_case_number LIKE {ValidationDefaults.CurrentCaseId} || '%'
               )
               AND a.activity_date_time >= '{ValidationDefaults.BadDataStartDate}'
               AND NVL(UPPER(TRIM(a.activity_user_id)), '~') NOT IN ('JISJDW', 'PNX2JIS', 'SYSTEMA');
           
            {IValidation.Check("Human AUDIT_TRAIL activity exists on the case graph")}
           
           """;
}