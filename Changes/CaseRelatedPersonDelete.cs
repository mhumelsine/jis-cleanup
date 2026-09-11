namespace JisCleanup.TableChanges;

public sealed class CaseRelatedPersonDelete : DeleteTableChange
{
    public CaseRelatedPersonDelete()
        : base(new TableDefinition("JISJDW", "CASE_RELATED_PERSON", "CASE_RELATED_PERSON_ID"))
    {
    }

    public override string LoadContext()
        => """
            -- Uses shared v_case_defendant_id loaded by CaseDefendantDelete.
            """;

    public override string WherePredicate
        => """
            source_row.case_defendant_id = v_case_defendant_id
            """;
}
