namespace JisCleanup.Validations;

public class NoSharedArrestFirstAppearance : Validator
{
    protected override string Collect()
        => """
           SELECT COUNT(*) 
           INTO v_count
           FROM JISJDW.FIRST_APPEARANCE fa
           WHERE fa.arrest_id IN (SELECT COLUMN_VALUE FROM TABLE(v_arrest_ids))
             AND fa.case_defendant_id<>v_case_defendant_id;

           """;

    protected override string Check() => ExactlyZero("Arrest is shared by another first appearance");

    public override void Declares(BlockDeclarations declarations)
    {
    }
}