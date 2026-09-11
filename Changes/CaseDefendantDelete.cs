namespace JisCleanup.TableChanges;

public sealed class CaseDefendantDelete : DeleteTableChange
{
    public CaseDefendantDelete()
        : base(new TableDefinition("JISJDW", "CASE_DEFENDANT", "CASE_DEFENDANT_ID"))
    {
    }

    public override string LoadContext()
        => """
            SELECT MIN(case_defendant_id)
            INTO v_case_defendant_id
            FROM JISJDW.CASE_DEFENDANT
            WHERE cjis_spn = :cjis_spn
              AND cjis_case_number = :cjis_case_number;
            
            SELECT case_defendant_id
            INTO v_case_defendant_id
            FROM JISJDW.CASE_DEFENDANT
            WHERE case_defendant_id = v_case_defendant_id
            FOR UPDATE NOWAIT;
            """;

    public override string WherePredicate
        => """
            source_row.case_defendant_id = v_case_defendant_id
            """;
}
