namespace JisCleanup;

public sealed class CjisCaseDelete : DeleteTableChange
{
    public CjisCaseDelete()
        : base(new TableDefinition("JISJDW", "CJIS_CASE", "CASE_ID"))
    {
    }

    public override string WherePredicate
        => "case_id=v_case_id";
}
