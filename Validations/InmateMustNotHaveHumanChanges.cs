namespace JisCleanup.Validations;

public class InmateMustNotHaveHumanChanges : Validator
{
    protected override string Collect()
        => $"""
            SELECT COUNT(*)
            INTO v_count
            FROM JISJDW.INMATE
            WHERE inmate_id IN (SELECT COLUMN_VALUE FROM TABLE(v_inmate_ids))
            {ValidationDefaults.OnlySustemCreatedOrChanged}

            """;

    protected override string Check() => ExactlyZero("Inmate has human changes");

    public override void Declares(BlockDeclarations declarations)
    {
    }
}