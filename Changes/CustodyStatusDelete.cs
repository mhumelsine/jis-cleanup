namespace JisCleanup;

public sealed class CustodyStatusDelete : DeleteTableChange
{
    public CustodyStatusDelete()
        : base(new TableDefinition("JISJDW", "CUSTODY_STATUS", "CUSTODY_STATUS_ID"))
    {
    }

    public override string WherePredicate(Charge charge)
        => $"""
           EXISTS (
               SELECT *
               FROM JISREM.CJIS_DOCKET d
               WHERE d.CHARGE_ID = '{charge.ChargeId}'
               AND d.CHARGE_ID = source_row.CHARGE_ID
               AND d.row_state = 'BEFORE'
           )
           """;
}