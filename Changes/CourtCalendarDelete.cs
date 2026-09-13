namespace JisCleanup;

public sealed class CourtCalendarDelete : DeleteTableChange
{
    public CourtCalendarDelete()
        : base(new TableDefinition("JISJDW", "COURT_CALENDAR", "COURT_CALENDAR_ID"))
    {
    }

    public override string WherePredicate(Charge charge)
        => "court_calendar_id IN (SELECT COLUMN_VALUE FROM TABLE(v_cal_ids))";
}
