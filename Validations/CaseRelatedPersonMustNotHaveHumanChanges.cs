namespace JisCleanup.Validations;

public class CaseRelatedPersonNotHaveHumanChanges : Validator
{
    protected override string Collect()
        => $"""
           SELECT COUNT(*)
           INTO v_count
           FROM JISJDW.CASE_RELATED_PERSON
           WHERE case_defendant_id=v_case_defendant_id
           {ValidationDefaults.OnlySustemCreatedOrChanged}

           """;

    protected override string Check() => ExactlyZero("Case related person has human changes");

    public override void Declares(BlockDeclarations declarations)
    {
    }
}