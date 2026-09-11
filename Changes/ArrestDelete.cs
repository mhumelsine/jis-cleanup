namespace JisCleanup.TableChanges;

public sealed class ArrestDelete : DeleteTableChange
{
    public ArrestDelete()
        : base(new TableDefinition(
            "JISJDW",
            "ARREST",
            "ARREST_ID"))
    {
    }

    public override string WherePredicate
        => """
            source_row.arrest_id IN
            (
                SELECT COLUMN_VALUE
                FROM TABLE(v_arrest_id_list)
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
