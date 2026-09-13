using JisCleanup.Validations;

namespace JisCleanup;

public sealed class FaChargeDelete : DeleteTableChange
{
    public FaChargeDelete()
        : base(new TableDefinition("JISJDW", "FA_CHARGE", "FA_CHARGE_ID"))
    {
    }

    public override string WherePredicate(Charge charge)
        => $"""
           exists (
               select CJIS_DOCKET_ID
               from JISJDW.CHARGE c
               inner join JISJDW.V_PNX2JIS_BAD_DKT d
               on c.CHARGE_ID = d.CHARGE_ID
               where c.CHARGE_ID = source_row.CHARGE_ID
           )
           and source_row.CHARGE_ID = {charge.ChargeId}
           {ValidationDefaults.BadDataStartDate}
           {ValidationDefaults.OnlySystemCreatedOrChanged}
           """;
}
