namespace JisCleanup.TableChanges;

public sealed class ReleaseBondDelete : DeleteTableChange
{
    public ReleaseBondDelete()
        : base(new TableDefinition("JISJDW", "RELEASE_BOND", "BOND_ID"))
    {
    }

    public override string LoadContext()
        => """
            SELECT bond_row.bond_id
            BULK COLLECT INTO v_bond_id_list
            FROM JISJDW.RELEASE_BOND bond_row
            WHERE bond_row.charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_id_list))
            FOR UPDATE NOWAIT;
            """;

    public override string WherePredicate
        => """
            source_row.bond_id IN (SELECT COLUMN_VALUE FROM TABLE(v_bond_id_list))
            """;
}
