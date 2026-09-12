namespace JisCleanup;

public sealed class CustodyStatusDelete : DeleteTableChange
{
    public CustodyStatusDelete()
        : base(new TableDefinition("JISJDW", "CUSTODY_STATUS", "CUSTODY_STATUS_ID"))
    {
    }

    public override string WherePredicate
        => "charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids))";
}
