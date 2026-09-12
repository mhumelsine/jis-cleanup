namespace JisCleanup.Validations;

public class CustodyMustNotHaveHumanChanges : Validator
{
    protected override string Collect()
        => $"""
            SELECT COUNT(*)
            INTO v_count
            FROM JISJDW.CUSTODY_STATUS
            WHERE charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids))   
            {ValidationDefaults.OnlySustemCreatedOrChanged}

            """;

    protected override string Check() => ExactlyZero("Custody has human changes");

    public override void Declares(BlockDeclarations declarations)
    {
    }
}