namespace JisCleanup;

public sealed class CaseRelatedPersonDelete : DeleteTableChange
{
    public CaseRelatedPersonDelete()
        : base(new TableDefinition("JISJDW", "CASE_RELATED_PERSON", "CASE_RELATED_PERSON_ID"))
    {
    }

    public override string WherePredicate(Charge charge)
        => $"source_row.CASE_DEFENDANT_ID = {charge.CaseDefendantId}";
}
