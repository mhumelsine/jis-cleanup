namespace JisCleanup.Validations;

public class NoDocketsOutsideBadDocketScope : Validator
{
    protected override string Collect()
        => """
           SELECT COUNT(*) 
           INTO v_count
           FROM JISJDW.CJIS_DOCKET d
           WHERE d.charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids))
             AND NOT EXISTS(
                SELECT 1 
                FROM JISJDW.V_PNX2JIS_BAD_DKT b
                WHERE b.cjis_docket_id=d.cjis_docket_id
            );

           """;

    protected override string Check() => ExactlyZero("Case contains a docket outside the bad docket scope");

    public override void Declares(BlockDeclarations declarations)
    {
    }
}