namespace JisCleanup;

public abstract class DeleteTableChange : TableChange
{
    protected DeleteTableChange(TableDefinition tableDefinition) 
        : base(tableDefinition, ActionType.Delete)
    {
    }

    public override void AddDeclares(BlockDeclarations declare)
    {
        //declare.AddType($"t_{TableDefinition.PrimaryKeyColumn}", $"IS TABLE OF {TargetTableName}.{TableDefinition.PrimaryKeyColumn}%TYPE");
        
        //declare.AddVariable($"{AffectedIdListName}", $"t_{TableDefinition.PrimaryKeyColumn}");
    }

    protected override string Apply(Charge charge)
        => $"""
            DELETE 
            FROM {TargetTableName} source_row
            WHERE {WherePredicate(charge)};

            """;

    public override string AfterSnapshot(Charge charge)
        => "";
    // IF {AffectedIdListName}.COUNT > 0 THEN
    //     FORALL index_value IN 1 .. {AffectedIdListName}.COUNT
    //         INSERT INTO {SnapshotTableName}
    //         (
    //             {TableDefinition.PrimaryKeyColumn},
    //             cleanup_id,
    //             change_action,
    //             row_state
    //         )
    //         VALUES
    //         (
    //             {AffectedIdListName}(index_value),
    //             __CLEANUP_ID__,
    //             '{Action.Value}',
    //             '{SnapshotType.After.Value}'
    //         );
    // END IF;
    //
    // """;
}