namespace JisCleanup.TableChanges;

public sealed class FaChargeDelete : DeleteTableChange
{
    public FaChargeDelete()
        : base(new TableDefinition("JISJDW", "FA_CHARGE", "FIRST_APPEARANCE_ID"))
    {
    }

    public override string LoadContext()
        => """
            -- Uses v_charge_id_list and v_first_appearance_id_list loaded by their owning changes.
            """;

    public override string WherePredicate
        => """
            source_row.charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_id_list)) OR source_row.first_appearance_id IN (SELECT COLUMN_VALUE FROM TABLE(v_first_appearance_id_list))
            """;
}
