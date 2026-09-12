namespace JisCleanup.Validations;

public class CaseDefendantMustNotHaveHumanChanges : Validator
{
    protected override string Collect()
        => $"""
            SELECT COUNT(*)
            INTO v_count
            FROM JISJDW.CASE_DEFENDANT cd 
            WHERE cd.case_defendant_id=v_case_defendant_id
            {ValidationDefaults.OnlySustemCreatedOrChanged}

            """;

    protected override string Check() => ExactlyZero("Case defendant has human changes");

    public override void Declares(BlockDeclarations declarations)
    {
    }
}