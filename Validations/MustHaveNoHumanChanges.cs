namespace JisCleanup.Validations;

public class MustHaveNoHumanChanges : Validator
{
    protected override string Collect()
        => """
           SELECT COUNT(*) INTO v_count
           FROM JISJDW.AUDIT_TRAIL a
           WHERE a.cjis_spn=in_spn
             AND (a.cjis_case_number=v_caseno OR a.cjis_case_number LIKE v_caseno||'%')
             AND a.activity_date_time>=v_bad_start
             AND NVL(UPPER(TRIM(a.activity_user_id)),'~') NOT IN ('JISJDW','PNX2JIS','SYSTEMA');
           """;

    protected override string Check() => ExactlyZero("Appears to contain user modifications");

    public override void Declares(BlockDeclarations declarations)
    {
    }
}