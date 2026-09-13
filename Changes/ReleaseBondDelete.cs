namespace JisCleanup;

public sealed class ReleaseBondDelete : DeleteTableChange
{
    public ReleaseBondDelete()
        : base(new TableDefinition("JISJDW", "RELEASE_BOND", "BOND_ID"))
    {
    }

    public override string WherePredicate(Charge charge)
        => "bond_id IN (SELECT COLUMN_VALUE FROM TABLE(v_bond_ids))";
}
