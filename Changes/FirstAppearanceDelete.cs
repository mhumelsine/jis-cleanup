namespace JisCleanup;

public sealed class FirstAppearanceDelete : DeleteTableChange
{
    public FirstAppearanceDelete()
        : base(new TableDefinition("JISJDW", "FIRST_APPEARANCE", "FIRST_APPEARANCE_ID"))
    {
    }

    public override string WherePredicate(Charge charge)
        => $"""
            EXISTS (select *
                from JISJDW.CASE_DEFENDANT d
                WHERE CJIS_CASE_NUMBER = '{charge.GetCjisCaseNumber()}'
                  AND CJIS_SPN = '{charge.Spn}'
                  AND d.CASE_DEFENDANT_ID = source_row.CASE_DEFENDANT_ID
            )
            """;
}
