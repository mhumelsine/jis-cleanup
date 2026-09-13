namespace JisCleanup;

public sealed class CourtCalendarDelete : DeleteTableChange
{
    public CourtCalendarDelete()
        : base(new TableDefinition("JISJDW", "COURT_CALENDAR", "COURT_CALENDAR_ID"))
    {
    }

    public override string WherePredicate(Charge charge)
        => $"""
           EXISTS (select *
               from JISJDW.CASE_DEFENDANT d
               WHERE CJIS_CASE_NUMBER = '{charge.GetCjisCaseNumber()}'
                 AND CJIS_SPN = '{charge.Spn}'
                 AND d.CASE_DEFENDANT_ID = source_row.CASE_DEFENDANT_ID
           )
           """;
}
