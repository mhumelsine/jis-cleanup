namespace JisCleanup.Changes;

public class RestoreStatusLocation : UpdateChange
{
    public RestoreStatusLocation() 
        : base(new TableDefinition("JISJDW", "CHARGE", "CHARGE_ID"), ActionType.Updated)
    {
    }

    public override string WherePredicate(Charge charge)
        => $"{TableDefinition.PrimaryKeyColumn} = '{charge.ChargeId}'";

    protected override string Apply(Charge charge)
        => $"""
            UPDATE {TargetTableName}
            SET STATUS = '{charge.Status}',
                LOCATION = '{charge.Location}'
            WHERE {WherePredicate(charge)};
            
            """;
}