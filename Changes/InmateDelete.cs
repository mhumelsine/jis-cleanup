using JisCleanup.Validations;

namespace JisCleanup;

public sealed class InmateDelete : DeleteTableChange
{
    public InmateDelete()
        : base(new TableDefinition("JISJDW", "INMATE", "INMATE_ID"))
    {
    }

    public override string WherePredicate(Charge charge)
        => $"""
            exists (
                 select *
                 from JISREM.ARREST a
                 WHERE a.INMATE_ID = source_row.INMATE_ID
                 and a.CJIS_SPN = {charge.CjisSpn}
                 and a.cleanup_id = __CLEANUP_ID__
            )
            {ValidationDefaults.BadDataStartDate}
            {ValidationDefaults.OnlySystemCreatedOrChanged}
            """;
}