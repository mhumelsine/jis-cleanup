namespace JisCleanup;

public sealed class ChargeJailInfoDelete : DeleteTableChange
{
    public ChargeJailInfoDelete()
        : base(new TableDefinition("JISJDW", "CHARGE_JAIL_INFO", "CHARGE_ID"))
    {
    }

    public override string WherePredicate
        => "charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids))";
}
