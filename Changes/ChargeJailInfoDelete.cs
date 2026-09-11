namespace JisCleanup.TableChanges;

public sealed class ChargeJailInfoDelete : DeleteTableChange
{
    public ChargeJailInfoDelete()
        : base(new TableDefinition("JISJDW", "CHARGE_JAIL_INFO", "CHARGE_ID"))
    {
    }

    public override string LoadContext()
        => """
            -- Uses v_charge_id_list loaded by ChargeDelete.
            """;

    public override string WherePredicate
        => """
            source_row.charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_id_list))
            """;
}
