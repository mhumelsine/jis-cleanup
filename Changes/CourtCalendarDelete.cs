namespace JisCleanup.TableChanges;

public sealed class CourtCalendarDelete : DeleteTableChange
{
    public CourtCalendarDelete()
        : base(new TableDefinition("JISJDW", "COURT_CALENDAR", "COURT_CALENDAR_ID"))
    {
    }

    public override string LoadContext()
        => """
            SELECT calendar_row.court_calendar_id
            BULK COLLECT INTO v_court_calendar_id_list
            FROM JISJDW.COURT_CALENDAR calendar_row
            WHERE calendar_row.case_defendant_id = v_case_defendant_id
            FOR UPDATE NOWAIT;
            """;

    public override string WherePredicate
        => """
            source_row.court_calendar_id IN (SELECT COLUMN_VALUE FROM TABLE(v_court_calendar_id_list))
            """;
}
