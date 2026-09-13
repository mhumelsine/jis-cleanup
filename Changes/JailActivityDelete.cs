using JisCleanup.Validations;

namespace JisCleanup;

public sealed class JailActivityDelete : DeleteTableChange
{
    public JailActivityDelete()
        : base(new TableDefinition("JISJDW", "JAIL_ACTIVITY", "JAIL_ACTIVITY_ID"))
    {
    }

    public override string WherePredicate(Charge charge)
        => $"""
           exists (
                select *
                from JISREM.ARREST a
                WHERE a.INMATE_ID = source_row.INMATE_ID
                and a.CJIS_SPN = '{charge.CjisSpn}'
                AND a.cleanup_id = __CLEANUP_ID__
           )
           {ValidationDefaults.BadDataStartDate}
           {ValidationDefaults.OnlySystemCreatedOrChanged}
           """;
}
