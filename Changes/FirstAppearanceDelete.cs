using JisCleanup.Validations;

namespace JisCleanup;

public sealed class FirstAppearanceDelete : DeleteTableChange
{
    public FirstAppearanceDelete()
        : base(new TableDefinition("JISJDW", "FIRST_APPEARANCE", "FIRST_APPEARANCE_ID"))
    {
    }

    public override string WherePredicate(Charge charge)
        => $"""
            source_row.CASE_DEFENDANT_ID = {charge.CaseDefendantId}
            {ValidationDefaults.BadDataStartDate}
            {ValidationDefaults.OnlySystemCreatedOrChanged}
            """;
}
