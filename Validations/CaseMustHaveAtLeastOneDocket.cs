namespace JisCleanup.Validations;

public class CaseMustHaveAtLeastOneDocket : Validator
{
    protected override string Collect()
        => """
           SELECT d.cjis_docket_id BULK COLLECT INTO v_docket_ids
           FROM JISJDW.CJIS_DOCKET d
           WHERE d.charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids));

           v_docket_count := v_docket_ids.COUNT;
           v_count := v_docket_ids.COUNT;
                          
           """;

    protected override string Check() => NotZero("Case has no dockets");

    public override void Declares(BlockDeclarations declarations)
    {
        declarations.AddVariable("v_docket_count", "NUMBER");
    }
}