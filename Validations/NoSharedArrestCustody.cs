namespace JisCleanup.Validations;

public class NoSharedArrestCustody : Validator
{
    protected override string Collect()
        => """
           SELECT DISTINCT arrest_id BULK COLLECT INTO v_arrest_ids
           FROM
           (
               SELECT arrest_id FROM JISJDW.CUSTODY_STATUS
                WHERE charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids))
               UNION
               SELECT arrest_id FROM JISJDW.CJIS_DOCKET
                WHERE cjis_docket_id IN (SELECT COLUMN_VALUE FROM TABLE(v_docket_ids))
               UNION
               SELECT arrest_id FROM JISJDW.FIRST_APPEARANCE
                WHERE first_appearance_id IN (SELECT COLUMN_VALUE FROM TABLE(v_fa_ids))
           ) WHERE arrest_id IS NOT NULL;
           v_arrest_count := v_arrest_ids.COUNT;

           -- Any custody tied to a candidate arrest must belong to this case's charges.
           SELECT COUNT(*) 
           INTO v_count
           FROM JISJDW.CUSTODY_STATUS cs
           WHERE cs.arrest_id IN (SELECT COLUMN_VALUE FROM TABLE(v_arrest_ids))
             AND cs.charge_id NOT IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids));

           """;

    protected override string Check() => ExactlyZero("Arrest is shared by custody on another charge");

    public override void Declares(BlockDeclarations declarations)
    {
        declarations.AddVariable("v_arrest_count", "PLS_INTEGER");
        declarations.AddVariable("v_arrest_ids", "SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST()");
    }
}