namespace JisCleanup;

public sealed class CjisDocketDelete : DeleteTableChange
{
    public CjisDocketDelete()
        : base(new TableDefinition("JISJDW", "CJIS_DOCKET", "CJIS_DOCKET_ID"))
    {
    }

    public override string WherePredicate
        => "cjis_docket_id IN (SELECT COLUMN_VALUE FROM TABLE(v_docket_ids))";
}
