namespace JisCleanup.TableChanges;

public sealed class ChargeDelete : DeleteTableChange
{
    public ChargeDelete()
        : base(new TableDefinition(
            "JISJDW",
            "CHARGE",
            "CHARGE_ID"))
    {
    }

    public override string WherePredicate
        => """
            source_row.case_defendant_id IN
            (
                SELECT case_defendant_row.case_defendant_id
                FROM JISJDW.CASE_DEFENDANT case_defendant_row
                WHERE case_defendant_row.case_id = v_case_id
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
