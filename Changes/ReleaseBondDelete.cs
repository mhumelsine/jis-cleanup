namespace JisCleanup;

public sealed class ReleaseBondDelete : DeleteTableChange
{
    public ReleaseBondDelete()
        : base(new TableDefinition("JISJDW", "RELEASE_BOND", "BOND_ID"))
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
            """;
}
