namespace JisCleanup;

public sealed class ArrestDelete : DeleteTableChange
{
    public ArrestDelete()
        : base(new TableDefinition("JISJDW", "ARREST", "ARREST_ID"))
    {
    }

    public override string WherePredicate(Charge charge)
        => $"""
           exists (
               select ARREST_ID
               from JISREM.CUSTODY_STATUS cs
               WHERE CHARGE_ID = '{charge.ChargeId}'
               AND cs.ARREST_ID = source_row.ARREST_ID
               AND fa.row_state = 'BEFORE'
               AND cs.cleanup_id = __CLEANUP_ID__
               
               UNION
               
               select ARREST_ID
               from JISREM.CJIS_DOCKET cd
               WHERE CHARGE_ID = '{charge.ChargeId}'
               AND cd.ARREST_ID = source_row.ARREST_ID
               AND fa.row_state = 'BEFORE'
               AND cd.cleanup_id = __CLEANUP_ID__
               
               UNION
               
               select ARREST_ID
               from JISREM.FIRST_APPEARANCE fa 
               WHERE CHARGE_ID = '{charge.ChargeId}'
               AND fa.ARREST_ID = source_row.ARREST_ID
               AND fa.row_state = 'BEFORE'
               AND fa.cleanup_id = __CLEANUP_ID__
           )
           """;
}
