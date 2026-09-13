namespace JisCleanup;

public abstract class InsertTableChange : TableChange
{
    private readonly string _sequenceName;

    public InsertTableChange(TableDefinition tableDefinition, string sequenceName) 
        : base(tableDefinition, ActionType.Insert)
    {
        _sequenceName = sequenceName;
    }

    public override string WherePredicate(Charge charge) 
        => "CJIS_DOCKET_ID = v_inserted_id";

    public override string BeforeSnapshot(Charge charge)
        => $"""
            v_inserted_id := {_sequenceName}.NEXTVAL;

            """;
            //
            // INSERT INTO {SnapshotTableName}
            // (
            //     {TableDefinition.PrimaryKeyColumn},
            //     cleanup_id,
            //     change_action,
            //     row_state
            // )
            // VALUES
            // (
            //     v_inserted_id,
            //     __CLEANUP_ID__,
            //     '{Action.Value}',
            //     '{SnapshotType.Before.Value}'
            // );
            //
            // """;

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