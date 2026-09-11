namespace JisCleanup.TableChanges;

public sealed class CjisCaseDelete : DeleteTableChange
{
    public CjisCaseDelete()
        : base(new TableDefinition("JISJDW", "CJIS_CASE", "CASE_ID"))
    {
    }

    public override string LoadContext()
        => """
            SELECT case_id
            INTO v_case_id
            FROM JISJDW.CASE_DEFENDANT
            WHERE case_defendant_id = v_case_defendant_id;
            
            SELECT case_id
            INTO v_case_id
            FROM JISJDW.CJIS_CASE
            WHERE case_id = v_case_id
            FOR UPDATE NOWAIT;
            """;

    public override string WherePredicate
        => """
            source_row.case_id = v_case_id
            """;
}
