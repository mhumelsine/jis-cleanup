namespace JisCleanup;

public abstract class DeleteTableChange : TableChange
{
    protected DeleteTableChange(TableDefinition tableDefinition) 
        : base(tableDefinition, ActionType.Delete)
    {
    }

    public override string Apply()
        => $"""
            DELETE 
            FROM {TargetTableName} source_row
            WHERE {WherePredicate}
            RETURNING
                source_row.{TableDefinition.PrimaryKeyColumn}
            BULK COLLECT INTO
                {AffectedIdListName};
            """;

    public override string AfterSnapshot()
        => $"""
            IF {AffectedIdListName}.COUNT > 0 THEN
                FORALL index_value IN 1 .. {AffectedIdListName}.COUNT
                    INSERT INTO {SnapshotTableName}
                    (
                        {TableDefinition.PrimaryKeyColumn},
                        cleanup_id,
                        change_action,
                        row_state
                    )
                    VALUES
                    (
                        {AffectedIdListName}(index_value),
                        :cleanup_id,
                        '{Action.Value}',
                        '{SnapshotType.After.Value}'
                    );
            END IF;
            """;
}