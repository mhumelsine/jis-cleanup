namespace JisCleanup;

public sealed class CaseRelatedPersonDelete : DeleteTableChange
{
    public CaseRelatedPersonDelete()
        : base(new TableDefinition("JISJDW", "CASE_RELATED_PERSON", "CASE_RELATED_PERSON_ID"))
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
