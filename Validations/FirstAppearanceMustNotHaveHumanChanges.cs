namespace JisCleanup.Validations;

public class FirstAppearanceMustNotHaveHumanChanges : Validator
{
    protected override string Collect()
        => $"""
            SELECT COUNT(*)
            INTO v_count
            FROM JISJDW.FIRST_APPEARANCE
            WHERE first_appearance_id IN (SELECT COLUMN_VALUE FROM TABLE(v_fa_ids))
            {ValidationDefaults.OnlySustemCreatedOrChanged}

            """;

    protected override string Check() => ExactlyZero("First appearance has human changes");

    public override void Declares(BlockDeclarations declarations)
    {
    }
}