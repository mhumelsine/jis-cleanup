namespace JisCleanup;

public sealed class JailActivityDelete : DeleteTableChange
{
    public JailActivityDelete()
        : base(new TableDefinition("JISJDW", "JAIL_ACTIVITY", "JAIL_ACTIVITY_ID"))
    {
    }

    public override string WherePredicate(Charge charge)
        => "inmate_id IN (SELECT COLUMN_VALUE FROM TABLE(v_inmate_ids))";
}
