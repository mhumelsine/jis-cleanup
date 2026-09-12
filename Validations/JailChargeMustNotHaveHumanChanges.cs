namespace JisCleanup.Validations;

public class JailChargeMustNotHaveHumanChanges : Validator
{
    protected override string Collect()
        => $"""
            SELECT COUNT(*)
            INTO v_count
            FROM JISJDW.CHARGE_JAIL_INFO
            WHERE charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids))
            {ValidationDefaults.OnlySustemCreatedOrChanged}

            """;

    protected override string Check() => ExactlyZero("Release bond has human changes");

    public override void Declares(BlockDeclarations declarations)
    {
    }
}