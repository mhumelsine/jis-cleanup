namespace JisCleanup.Validations;

public class ArrestMustNotHaveHumanChanges : Validator
{
    //TODO:  I'm worried about null with NOT IN;
    protected override string Collect()
        => $"""
            SELECT COUNT(*) 
            INTO v_count
            FROM JISJDW.ARREST a
            WHERE a.arrest_id IN (SELECT COLUMN_VALUE FROM TABLE(v_arrest_ids))
            {ValidationDefaults.OnlySustemCreatedOrChanged}

            """;

    protected override string Check() => ExactlyZero("Arrest has human activity");

    public override void Declares(BlockDeclarations declarations)
    {
        
    }
}