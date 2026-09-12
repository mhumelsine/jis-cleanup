namespace JisCleanup.Validations;

public class MustHaveAtLeastOneCharge : Validator
{
    protected override string Collect()
        => """
           SELECT charge_id BULK COLLECT INTO v_charge_ids
           FROM JISJDW.CHARGE ch
           WHERE ch.case_defendant_id=v_case_defendant_id;

           v_count := v_charge_ids.COUNT;
           """;

    protected override string Check() => NotZero("Case has not charges");

    public override void Declares(BlockDeclarations declarations)
    {
        declarations.AddVariable("v_charge_ids", "SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST()");
    }
}