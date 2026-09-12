namespace JisCleanup.Validations;

public class NoArrestOutsideGhostDocket : Validator
{
    protected override string Collect()
        => """
           SELECT COUNT(*) 
           INTO v_count
           FROM JISJDW.CJIS_DOCKET d
           WHERE d.arrest_id IN (SELECT COLUMN_VALUE FROM TABLE(v_arrest_ids))
             AND d.cjis_docket_id NOT IN (SELECT COLUMN_VALUE FROM TABLE(v_docket_ids));

           """;

    protected override string Check() 
        => ExactlyZero("Arrest is referenced by a docket outside the ghost docket");

    public override void Declares(BlockDeclarations declarations)
    {
        declarations.AddVariable("v_docket_ids", "SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST()");
    }
}