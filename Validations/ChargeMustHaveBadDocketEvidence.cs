namespace JisCleanup.Validations;

public class ChargeMustHaveBadDocketEvidence : Validator
{
    //TODO:  The error does not seem to match the code
    protected override string Collect()
        => """
           SELECT COUNT(*) INTO v_count
           FROM TABLE(v_charge_ids) x
           WHERE NOT EXISTS (
               SELECT 1 
               FROM JISJDW.V_PNX2JIS_BAD_DKT b 
               WHERE b.charge_id=x.COLUMN_VALUE
           );

           """;

    protected override string Check() => ExactlyZero("One or more charges have no bad docket evidence");

    public override void Declares(BlockDeclarations declarations)
    {
        
    }
}