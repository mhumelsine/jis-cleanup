namespace JisCleanup.TableChanges;

public sealed class FaChargeDelete : DeleteTableChange
{
    public FaChargeDelete()
        : base(new TableDefinition(
            "JISJDW",
            "FA_CHARGE",
            "FIRST_APPEARANCE_ID"))
    {
    }

    public override string WherePredicate
        => """
            source_row.charge_id IN
            (
                SELECT charge_row.charge_id
                FROM JISJDW.CHARGE charge_row
                WHERE charge_row.case_defendant_id IN
                (
                    SELECT case_defendant_row.case_defendant_id
                    FROM JISJDW.CASE_DEFENDANT case_defendant_row
                    WHERE case_defendant_row.case_id = v_case_id
                )
            )
            OR source_row.first_appearance_id IN
            (
                SELECT appearance_row.first_appearance_id
                FROM JISJDW.FIRST_APPEARANCE appearance_row
                WHERE appearance_row.case_defendant_id IN
                (
                    SELECT case_defendant_row.case_defendant_id
                    FROM JISJDW.CASE_DEFENDANT case_defendant_row
                    WHERE case_defendant_row.case_id = v_case_id
                )
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
