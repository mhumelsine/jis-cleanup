namespace JisCleanup;

public abstract class DeleteTableChange : TableChange
{
    protected DeleteTableChange(TableDefinition tableDefinition) 
        : base(tableDefinition, ActionType.Delete)
    {
    }

    public override void AddDeclares(BlockDeclarations declare)
    {
        declare.AddType($"t_{TableDefinition.PrimaryKeyColumn}", $"IS TABLE OF {TargetTableName}.{TableDefinition.PrimaryKeyColumn}%TYPE");
        
        declare.AddVariable($"{AffectedIdListName}", $"t_{TableDefinition.PrimaryKeyColumn}");
    }

    public override string Apply()
        => $"""
            DELETE 
            FROM {TargetTableName}
            WHERE {WherePredicate}
            RETURNING
                {TableDefinition.PrimaryKeyColumn}
            BULK COLLECT INTO
                {AffectedIdListName};

            """;

    public override string AfterSnapshot()
        => $"""
            --SNAPSHOT AFTER
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