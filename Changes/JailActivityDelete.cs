namespace JisCleanup.TableChanges;

public sealed class JailActivityDelete : DeleteTableChange
{
    public JailActivityDelete()
        : base(new TableDefinition("JISJDW", "JAIL_ACTIVITY", "JAIL_ACTIVITY_ID"))
    {
    }

    public override string LoadContext()
        => """
            -- Uses v_inmate_id_list loaded by InmateDelete.
            """;

    public override string WherePredicate
        => """
            source_row.inmate_id IN (SELECT COLUMN_VALUE FROM TABLE(v_inmate_id_list))
            """;
}
