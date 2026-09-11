namespace JisCleanup.TableChanges;

public sealed class CustodyStatusDelete : DeleteTableChange
{
    public CustodyStatusDelete()
        : base(new TableDefinition("JISJDW", "CUSTODY_STATUS", "CUSTODY_STATUS_ID"))
    {
    }

    public override string LoadContext()
        => """
            -- Uses v_charge_id_list loaded by ChargeDelete.
            """;

    public override string WherePredicate
        => """
            source_row.charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_id_list))
            """;
}
