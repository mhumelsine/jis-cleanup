namespace JisCleanup;

public sealed class FirstAppearanceDelete : DeleteTableChange
{
    public FirstAppearanceDelete()
        : base(new TableDefinition("JISJDW", "FIRST_APPEARANCE", "FIRST_APPEARANCE_ID"))
    {
    }

    public override string WherePredicate
        => """
            EXISTS
            (
                SELECT 1
                FROM JISJDW.CASE_DEFENDANT cd
                WHERE cd.case_defendant_id = source_row.case_defendant_id
                  AND cd.case_id = v_case_id
            )
            """;
}
