namespace JisCleanup;

public sealed class FaChargeDelete : DeleteTableChange
{
    public FaChargeDelete()
        : base(new TableDefinition("JISJDW", "FA_CHARGE", "FIRST_APPEARANCE_ID"))
    {
    }

    public override string WherePredicate
        => """
           charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids))
           OR first_appearance_id IN (SELECT COLUMN_VALUE FROM TABLE(v_fa_ids))
           """;
}
