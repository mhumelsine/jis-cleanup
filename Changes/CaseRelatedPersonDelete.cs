namespace JisCleanup;

public sealed class CaseRelatedPersonDelete : DeleteTableChange
{
    public CaseRelatedPersonDelete()
        : base(new TableDefinition("JISJDW", "CASE_RELATED_PERSON", "CASE_RELATED_PERSON_ID"))
    {
    }

    public override string WherePredicate(Charge charge)
        => "case_defendant_id=v_case_defendant_id";
}
