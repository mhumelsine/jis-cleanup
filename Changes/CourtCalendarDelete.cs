using JisCleanup.Validations;

namespace JisCleanup;

public sealed class CourtCalendarDelete : DeleteTableChange
{
    public CourtCalendarDelete()
        : base(new TableDefinition("JISJDW", "COURT_CALENDAR", "COURT_CALENDAR_ID"))
    {
    }

    public override string WherePredicate(Charge charge)
        => $"""
           source_row.CASE_DEFENDANT_ID = {charge.CaseDefendantId}
           AND source_row.CALENDAR_TYPE = 'FAP'
           {ValidationDefaults.BadDataStartDate}
           {ValidationDefaults.OnlySystemCreatedOrChanged}
           """;
}
