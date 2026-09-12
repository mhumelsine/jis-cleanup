namespace JisCleanup.Validations;

public class JailActivityMustNotHaveHumanChanges : Validator
{
    protected override string Collect()
        => $"""
            SELECT COUNT(*)
            INTO v_count
            FROM JISJDW.JAIL_ACTIVITY
            WHERE inmate_id IN (SELECT COLUMN_VALUE FROM TABLE(v_inmate_ids))
            {ValidationDefaults.OnlySustemCreatedOrChanged}

            """;

    protected override string Check() => ExactlyZero("Jail activity has human changes");

    public override void Declares(BlockDeclarations declarations)
    {
    }
}