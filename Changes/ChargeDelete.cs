namespace JisCleanup.TableChanges;

public sealed class ChargeDelete : DeleteTableChange
{
    public ChargeDelete()
        : base(new TableDefinition("JISJDW", "CHARGE", "CHARGE_ID"))
    {
    }

    public override string LoadContext()
        => """
            SELECT charge_row.charge_id
            BULK COLLECT INTO v_charge_id_list
            FROM JISJDW.CHARGE charge_row
            WHERE charge_row.case_defendant_id = v_case_defendant_id
            FOR UPDATE NOWAIT;
            """;

    public override string WherePredicate
        => """
            source_row.charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_id_list))
            """;
}
