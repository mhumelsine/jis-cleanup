namespace JisCleanup.Validations;

public class BondMustNotHaveHumanChanges : Validator
{
    protected override string Collect()
        => $"""
            SELECT COUNT(*)
            INTO v_count
            FROM JISJDW.RELEASE_BOND
            WHERE bond_id IN (SELECT COLUMN_VALUE FROM TABLE(v_bond_ids))
            {ValidationDefaults.OnlySustemCreatedOrChanged}

            """;

    protected override string Check() => ExactlyZero("Release bond has human changes");

    public override void Declares(BlockDeclarations declarations)
    {
    }
}