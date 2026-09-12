namespace JisCleanup.Validations;

public class MustBeSingleDefendant : Validator
{
    //TODO:  We do not have SPN
    protected override string Collect()
        => """
           SELECT COUNT(*),MIN(case_defendant_id)
           INTO v_count,v_case_defendant_id
           FROM JISJDW.CASE_DEFENDANT cd
           WHERE cd.cjis_spn=in_spn AND cd.cjis_case_number=v_case_id;

           """;

    protected override string Check() => ExactlyOne("Must only have a single defendant");

    public override void Declares(BlockDeclarations declarations)
    {
        declarations.AddVariable("v_case_defendant_id", "JISJDW.CASE_DEFENDANT.CASE_DEFENDANT_ID%TYPE");
    }
}