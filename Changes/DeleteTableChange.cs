namespace JisCleanup;

public abstract class DeleteTableChange : TableChange
{
    protected DeleteTableChange(TableDefinition tableDefinition) 
        : base(tableDefinition, ActionType.Delete)
    {
    }

    public override void AddDeclares(BlockDeclarations declare)
    {
    }

    protected override string Apply(Charge charge)
        => $"""
            DELETE 
            FROM {TargetTableName} source_row
            WHERE {WherePredicate(charge)};

            """;

    public override string AfterSnapshot(Charge charge)
        => "";
}