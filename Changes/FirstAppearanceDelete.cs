namespace JisCleanup.TableChanges;

public sealed class FirstAppearanceDelete : DeleteTableChange
{
    public FirstAppearanceDelete()
        : base(new TableDefinition("JISJDW", "FIRST_APPEARANCE", "FIRST_APPEARANCE_ID"))
    {
    }

    public override string LoadContext()
        => """
            SELECT fa_row.first_appearance_id
            BULK COLLECT INTO v_first_appearance_id_list
            FROM JISJDW.FIRST_APPEARANCE fa_row
            WHERE fa_row.case_defendant_id = v_case_defendant_id
            FOR UPDATE NOWAIT;
            """;

    public override string WherePredicate
        => """
            source_row.first_appearance_id IN (SELECT COLUMN_VALUE FROM TABLE(v_first_appearance_id_list))
            """;
}
