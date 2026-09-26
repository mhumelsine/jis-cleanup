namespace JisCleanup.Validations;

public class NoHumanChargeActivity : Validator
{
    protected override string Collect(Charge charge)
        => $"""
            SELECT COUNT(*)
            INTO v_count
            FROM JISJDW.audit_trail 
            WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
            AND cjis_case_number = '{charge.CjisCaseNumber}'
            AND ACTIVITY_TABLE_NAME = 'CHARGE'
            and (ACTIVITY_DETAILS LIKE '%STATUS%'
              OR ACTIVITY_DETAILS LIKE '%LOCATION%'
              OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
              )
            AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
                OR activity_user_id is null
            );
                   
            """;

    protected override string Check() => ExactlyZero("Human activity found in Audit Trail");

    public override void Declares(BlockDeclarations declarations)
    {
        
    }
}