namespace JisCleanup.Validations;

public class NoStatusOrLocationChanges : Validator
{
    protected override string Collect(Charge charge)
        => $"""

            select
                ACTIVITY_TABLE_NAME
                ,ACTIVITY_DETAILS
                ,CJIS_CASE_NUMBER
            from JISJDW.AUDIT_TRAIL
            WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
            AND CJIS_CASE_NUMBER = '{charge.CjisCaseNumber}'
            AND ((
                ACTIVITY_TABLE_NAME = 'CUSTODY'
                AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
            OR (
                     ACTIVITY_TABLE_NAME = 'CHARGE'
                         AND ACTIVITY_DETAILS LIKE '%STATUS%'
                     ))
            """;

    protected override string Check() => ExactlyZero("Changes to STATUS or LOCATION detected");

    public override void Declares(BlockDeclarations declarations)
    {
        
    }
}