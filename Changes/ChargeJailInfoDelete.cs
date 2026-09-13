namespace JisCleanup;

public sealed class ChargeJailInfoDelete : DeleteTableChange
{
    public ChargeJailInfoDelete()
        : base(new TableDefinition("JISJDW", "CHARGE_JAIL_INFO", "CHARGE_ID"))
    {
    }

    public override string WherePredicate(Charge charge)
        => $"source_row.CHARGE_ID = '{charge.ChargeId}'";
}
