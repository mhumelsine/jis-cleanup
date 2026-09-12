namespace JisCleanup;

public sealed class InmateDelete : DeleteTableChange
{
    public InmateDelete()
        : base(new TableDefinition("JISJDW", "INMATE", "INMATE_ID"))
    {
    }

    public override string WherePredicate
        => "inmate_id IN (SELECT COLUMN_VALUE FROM TABLE(v_inmate_ids))";
}
