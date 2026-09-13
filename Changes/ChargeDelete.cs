namespace JisCleanup;

public sealed class ChargeDelete : DeleteTableChange
{
    public ChargeDelete()
        : base(new TableDefinition("JISJDW", "CHARGE", "CHARGE_ID"))
    {
    }

    public override string WherePredicate(Charge charge)
        => "charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids))";
}
