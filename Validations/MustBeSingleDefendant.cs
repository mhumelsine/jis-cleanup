namespace JisCleanup.Validations;

public class MustBeSingleDefendant : Validator
{
    protected override string Collect()
        => """
           SELECT COUNT(*),MIN(case_id),MIN(case_defendant_id)
           INTO v_count,v_case_id,v_case_defendant_id
           FROM JISJDW.CASE_DEFENDANT cd
           WHERE cd.cjis_spn=in_spn AND cd.cjis_case_number=v_case_id;

           """;

    protected override string Check() => ExactlyOne("Multiple defendants found");

    public override void Declares(BlockDeclarations declarations)
    {
        declarations.AddVariable("v_case_id", "JISJDW.CASE_DEFENDANT.CJIS_CASE_NUMBER%TYPE;");
        declarations.AddVariable("v_defendant_id", "JISJDW.CASE_DEFENDANT.CASE_DEFENDANT_ID%TYPE;");
    }
}