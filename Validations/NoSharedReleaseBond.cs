namespace JisCleanup.Validations;

public class NoSharedReleaseBond : Validator
{
    protected override string Collect()
        => """
           SELECT COUNT(*) INTO v_count
           FROM JISJDW.CUSTODY_STATUS cs
           WHERE cs.bond_id IN (SELECT COLUMN_VALUE FROM TABLE(v_bond_ids))
            AND cs.charge_id NOT IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids));

           """;

    protected override string Check() => ExactlyZero("Release bond is shared by custody or another charge");

    public override void Declares(BlockDeclarations declarations)
    {
    }
}