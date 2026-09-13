namespace JisCleanup;

public sealed class FirstAppearanceDelete : DeleteTableChange
{
    public FirstAppearanceDelete()
        : base(new TableDefinition("JISJDW", "FIRST_APPEARANCE", "FIRST_APPEARANCE_ID"))
    {
    }

    public override string WherePredicate(Charge charge)
        => "first_appearance_id IN (SELECT COLUMN_VALUE FROM TABLE(v_fa_ids))";
}
