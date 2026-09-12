namespace JisCleanup.Validations;

public class CjisCaseMustNotHaveHumanChanges : Validator
{
    protected override string Collect()
        => $"""
            SELECT COUNT(*)
            INTO v_count
            FROM JISJDW.CJIS_CASE c 
            WHERE c.case_id=v_case_id
            {ValidationDefaults.OnlySustemCreatedOrChanged}

            """;

    protected override string Check() => ExactlyZero("CJIS case has human changes");

    public override void Declares(BlockDeclarations declarations)
    {
    }
}