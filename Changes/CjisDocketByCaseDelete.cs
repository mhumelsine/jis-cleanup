using JisCleanup.Validations;

namespace JisCleanup.Changes;

public class CjisDocketByCaseDelete : DeleteTableChange
{
    public CjisDocketByCaseDelete() 
        : base(new TableDefinition("JISJDW", "CJIS_DOCKET", "CJIS_DOCKET_ID"))
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
                and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
                and REGEXP_SUBSTR(d.CJIS_CASE_NUMBER, '(\d\d\d\d\w\w\d+\w).+', 1,1,null,1) = {charge.GetCaseNumber()}
            )
            {ValidationDefaults.BadDataStartDate}
            {ValidationDefaults.OnlySystemCreatedOrChanged}
            """;
}