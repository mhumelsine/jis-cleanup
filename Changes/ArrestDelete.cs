namespace JisCleanup;

public sealed class ArrestDelete : DeleteTableChange
{
    public ArrestDelete()
        : base(new TableDefinition("JISJDW", "ARREST", "ARREST_ID"))
    {
    }

    public override string WherePredicate(Charge charge)
        => "arrest_id IN (SELECT COLUMN_VALUE FROM TABLE(v_arrest_ids))";
}
