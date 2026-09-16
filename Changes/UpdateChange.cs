namespace JisCleanup;

public abstract class UpdateChange : TableChange
{
    public UpdateChange(TableDefinition tableDefinition, ActionType action)
        : base(tableDefinition, action)
    {
    }
    

    public override string AfterSnapshot(Charge charge)
        => $"""
            --SNAPSHOT AFTER
            INSERT INTO {SnapshotTableName}
            SELECT
                source_row.*,
                __CLEANUP_ID__,
                '{Action.Value}',
                '{SnapshotType.After.Value}'
            FROM {TargetTableName} source_row
            WHERE {WherePredicate(charge)};

            """;
}