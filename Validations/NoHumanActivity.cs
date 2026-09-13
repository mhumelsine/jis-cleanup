using System.Text;

namespace JisCleanup.Validations;

public class NoHumanActivity : Validator
{
    protected override string Collect(Charge charge)
        => $"""
            SELECT COUNT(*)
            INTO v_count
            FROM audit_trail 
            WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
            AND cjis_case_number = '{charge.CjisChargeNumber}'
            AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS')
                OR activity_user_id is null
            );
                   
            """;

    protected override string Check() => ExactlyZero("Human activity found in Audit Trail");

    public override void Declares(BlockDeclarations declarations)
    {
        
    }
}