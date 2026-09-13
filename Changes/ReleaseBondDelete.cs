using JisCleanup.Validations;

namespace JisCleanup;

public sealed class ReleaseBondDelete : DeleteTableChange
{
    public ReleaseBondDelete()
        : base(new TableDefinition("JISJDW", "RELEASE_BOND", "BOND_ID"))
    {
    }

    public override string WherePredicate(Charge charge)
        => $"""
            source_row.CHARGE_ID = {charge.ChargeId}
            {ValidationDefaults.BadDataStartDate}
            {ValidationDefaults.OnlySystemCreatedOrChanged}
            """;
}
