namespace JisCleanup;

public abstract class TableChange
{
    protected TableDefinition TableDefinition;
    public ActionType Action { get; }
    
    public string ChangeName => $"{GetType().Name}__{Action.Value}";

    public string AffectedIdListName => $"v_{TableDefinition.PrimaryKeyColumn}_list".ToLower();

    public string SnapshotTableName => $"{TableDefinition.Owner}.Z__{TableDefinition.Table}";
    public string TargetTableName => $"{TableDefinition.Owner}.{TableDefinition.Table}";

    protected TableChange(TableDefinition tableDefinition, ActionType action)
    {
        TableDefinition = tableDefinition;
        Action = action;
    }

    public override string ToString() => $"{GetType().Name}::{Action.Value}";
    
    public string BeforeSnapshot()
        => $"""
            INSERT INTO {SnapshotTableName}
            SELECT
                source_row.*,
                :cleanup_id,
                '{Action.Value}',
                '{SnapshotType.Before.Value}'
            FROM {TargetTableName} source_row
            WHERE {WherePredicate}
            ;
            """;

    public abstract string WherePredicate { get; }

    public abstract string AfterSnapshot();

    public string LogOperation()
        => $"""
            INSERT INTO JISJDW.Z__CLEANUP_LOG
            (
                cleanup_id,
                case_id,
                log_sequence,
                step_code,
                affected_rows
            )
            VALUES
            (
                :cleanup_id,
                :case_id,
                JISJDW.Z__CLEANUP_LOG_SEQ.NEXTVAL,
                '{ChangeName}',
                {AffectedIdListName}.COUNT
            );
            """;

    public abstract string Apply();
}