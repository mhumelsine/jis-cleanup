namespace JisCleanup.Validations;

public class NoSharedFirstAppearance : Validator
{
    protected override string Collect()
        => """
           SELECT COUNT(*) 
           INTO v_count
           FROM JISJDW.FA_CHARGE fc
           WHERE fc.first_appearance_id IN (SELECT COLUMN_VALUE FROM TABLE(v_fa_ids))
           AND fc.charge_id NOT IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids));

           """;

    protected override string Check() 
        => ExactlyZero("First appearance is shared with a charge outside the ghost case");

    public override void Declares(BlockDeclarations declarations)
    {
        
    }
}