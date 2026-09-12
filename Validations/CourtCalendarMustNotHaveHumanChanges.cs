namespace JisCleanup.Validations;

public class CourtCalendarMustNotHaveHumanChanges : Validator
{
    protected override string Collect()
        => $"""
            SELECT COUNT(*)
            INTO v_count
            FROM JISJDW.COURT_CALENDAR
            WHERE court_calendar_id IN (SELECT COLUMN_VALUE FROM TABLE(v_cal_ids))
            {ValidationDefaults.OnlySustemCreatedOrChanged}

            """;

    protected override string Check() => ExactlyZero("Release bond has human changes");

    public override void Declares(BlockDeclarations declarations)
    {
    }
}