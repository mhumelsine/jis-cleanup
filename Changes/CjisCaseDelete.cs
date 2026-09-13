namespace JisCleanup;

public sealed class CjisCaseDelete : DeleteTableChange
{
    public CjisCaseDelete()
        : base(new TableDefinition("JISJDW", "CJIS_CASE", "CASE_ID"))
    {
    }

    public override string WherePredicate(Charge charge)
        => $"""
            "YEAR" = '{charge.GetCaseYear()}'
            AND SEQ = '{charge.GetCaseSequence()}'
            AND COURT_DESIGNATOR = '{charge.GetCaseCourt()}'
            """;
}