namespace JisCleanup.Validations;

public class NoFirstAppearanceOutsideGhostDocket : Validator
{
    protected override string Collect()
        => """
           SELECT first_appearance_id BULK COLLECT INTO v_fa_ids
           FROM JISJDW.FIRST_APPEARANCE fa
           WHERE fa.case_defendant_id=v_case_defendant_id;
           
           v_fa_count := v_fa_ids.COUNT;
                            
           SELECT COUNT(*) 
           INTO v_count
           FROM JISJDW.CJIS_DOCKET d
           WHERE d.first_appearance_id IN (SELECT COLUMN_VALUE FROM TABLE(v_fa_ids))
           AND d.cjis_docket_id NOT IN (SELECT COLUMN_VALUE FROM TABLE(v_docket_ids));

           """;

    protected override string Check() =>
        ExactlyZero("First appearance is referenced by a docket outside the ghost docket");

    public override void Declares(BlockDeclarations declarations)
    {
        declarations.AddVariable("v_fa_count", "PLS_INTEGER");
        declarations.AddVariable("v_fa_ids", "SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST()");
    }
}