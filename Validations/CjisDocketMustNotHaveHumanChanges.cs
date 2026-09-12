namespace JisCleanup.Validations;

public class CjisDocketMustNotHaveHumanChanges : Validator
{
    protected override string Collect()
        => $"""
            SELECT COUNT(*)
            INTO v_count
            FROM JISJDW.CJIS_DOCKET
            WHERE cjis_docket_id IN (SELECT COLUMN_VALUE FROM TABLE(v_docket_ids))
            {ValidationDefaults.OnlySustemCreatedOrChanged}

            """;

    protected override string Check() => ExactlyZero("CJIS Docket has human changes");

    public override void Declares(BlockDeclarations declarations)
    {
    }
}