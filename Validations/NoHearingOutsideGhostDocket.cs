namespace JisCleanup.Validations;

public class NoHearingOutsideGhostDocket : Validator
{
    protected override string Collect()
        => """
           SELECT court_calendar_id BULK COLLECT INTO v_cal_ids
           FROM JISJDW.COURT_CALENDAR cc
           WHERE cc.case_defendant_id=v_case_defendant_id
           FOR UPDATE NOWAIT;
           v_calendar_count := v_cal_ids.COUNT;
                            
           SELECT COUNT(*) 
           INTO v_count
           FROM JISJDW.CJIS_DOCKET d
           WHERE d.court_calendar_id IN (SELECT COLUMN_VALUE FROM TABLE(v_cal_ids))
           AND d.cjis_docket_id NOT IN (SELECT COLUMN_VALUE FROM TABLE(v_docket_ids));
           
           """;

    protected override string Check() =>
        ExactlyZero("Court calendar is referenced by a docket outside the ghost docket");

    public override void Declares(BlockDeclarations declarations)
    {
        declarations.AddVariable("v_calendar_count", "PLS_INTEGER");
        declarations.AddVariable("v_cal_ids", "SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST()");
    }
}