namespace JisCleanup;

public sealed class FaChargeDelete : DeleteTableChange
{
    public FaChargeDelete()
        : base(new TableDefinition("JISJDW", "FA_CHARGE", "FIRST_APPEARANCE_ID"))
    {
    }

    public override string WherePredicate
        => """
            EXISTS
            (
                SELECT 1
                FROM JISJDW.CHARGE ch
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = ch.case_defendant_id
                WHERE ch.charge_id = source_row.charge_id
                  AND cd.case_id = v_case_id
            )
            OR EXISTS
            (
                SELECT 1 FROM JISJDW.FIRST_APPEARANCE fa
                JOIN JISJDW.CASE_DEFENDANT cd ON cd.case_defendant_id = fa.case_defendant_id
                WHERE fa.first_appearance_id = source_row.first_appearance_id
                  AND cd.case_id = v_case_id
            )
            """;
}
