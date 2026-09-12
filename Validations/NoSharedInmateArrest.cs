namespace JisCleanup.Validations;

public class NoSharedInmateArrest : Validator
{
    protected override string Collect()
        => """
           SELECT DISTINCT inmate_id BULK COLLECT INTO v_inmate_ids
           FROM JISJDW.ARREST
           WHERE arrest_id IN (SELECT COLUMN_VALUE FROM TABLE(v_arrest_ids))
             AND inmate_id IS NOT NULL;
           v_inmate_count := v_inmate_ids.COUNT;
           
           SELECT COUNT(*) 
           INTO v_count
           FROM JISJDW.ARREST a
           WHERE a.inmate_id IN (SELECT COLUMN_VALUE FROM TABLE(v_inmate_ids))
             AND a.arrest_id NOT IN (SELECT COLUMN_VALUE FROM TABLE(v_arrest_ids));

           """;

    protected override string Check() => ExactlyZero("Inmate has an arrest outside ghost case");

    public override void Declares(BlockDeclarations declarations)
    {
        declarations.AddVariable("v_inmate_count", "PLS_INTEGER");
        declarations.AddVariable("v_inmate_ids", "SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST()");
    }
}