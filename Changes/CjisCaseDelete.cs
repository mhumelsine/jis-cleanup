namespace JisCleanup.TableChanges;

public sealed class CjisCaseDelete : DeleteTableChange
{
    public CjisCaseDelete()
        : base(new TableDefinition(
            "JISJDW",
            "CJIS_CASE",
            "CASE_ID"))
    {
    }

    public override string WherePredicate
        => """
            source_row.case_id = v_case_id
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
