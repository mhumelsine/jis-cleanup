namespace JisCleanup;

public sealed class ChargeDelete : DeleteTableChange
{
    public ChargeDelete()
        : base(new TableDefinition("JISJDW", "CHARGE", "CHARGE_ID"))
    {
    }

    public override string WherePredicate(Charge charge)
        => $"source_row.CHARGE_ID = {charge.ChargeId}";
}
