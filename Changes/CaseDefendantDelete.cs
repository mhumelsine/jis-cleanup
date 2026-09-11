namespace JisCleanup.TableChanges;

public sealed class CaseDefendantDelete : DeleteTableChange
{
    public CaseDefendantDelete()
        : base(new TableDefinition(
            "JISJDW",
            "CASE_DEFENDANT",
            "CASE_DEFENDANT_ID"))
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
