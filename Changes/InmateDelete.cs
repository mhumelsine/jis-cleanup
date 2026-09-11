namespace JisCleanup.TableChanges;

public sealed class InmateDelete : DeleteTableChange
{
    public InmateDelete()
        : base(new TableDefinition(
            "JISJDW",
            "INMATE",
            "INMATE_ID"))
    {
    }

    public override string WherePredicate
        => """
            source_row.inmate_id IN
            (
                SELECT COLUMN_VALUE
                FROM TABLE(v_inmate_id_list)
            )
            """;

    public override string Apply()
        => $"""
            DELETE
            FROM {TargetTableName} source_row
            WHERE {WherePredicate}
            RETURNING
                source_row.{TableDefinition.PrimaryKeyColumn}
            BULK COLLECT INTO
                {AffectedIdListName};
            """;
}
