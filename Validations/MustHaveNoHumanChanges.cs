namespace JisCleanup.Validations;

public class MustHaveNoHumanChanges : Validator
{
    //TODO:  We do not have SPN
    protected override string Collect()
        => """
           SELECT MIN(create_date_time) I
           NTO v_bad_start
           FROM JISJDW.CJIS_DOCKET
           WHERE cjis_docket_id IN (SELECT COLUMN_VALUE FROM TABLE(v_docket_ids));

           SELECT COUNT(*) 
           INTO v_count
           FROM JISJDW.AUDIT_TRAIL a
           WHERE a.cjis_spn=v_spn_id
             AND (a.cjis_case_number=v_caseno OR a.cjis_case_number LIKE v_caseno||'%')
             AND a.activity_date_time>=v_bad_start
             AND NVL(UPPER(TRIM(a.activity_user_id)),'~') NOT IN ('JISJDW','PNX2JIS','SYSTEMA');
           """;

    protected override string Check() => ExactlyZero("Appears to contain user modifications");

    public override void Declares(BlockDeclarations declarations)
    {
        declarations.AddVariable("v_bad_start", "DATE");
    }
}