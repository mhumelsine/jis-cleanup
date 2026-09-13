namespace JisCleanup;

public abstract class TableChange
{
    protected TableDefinition TableDefinition;
    
    public ActionType Action { get; }

    public string ChangeName => $"{GetType().Name}__{Action.Value}";

    public string AffectedIdListName => $"v_{TableDefinition.PrimaryKeyColumn}_list".ToLower();

    public string SnapshotTableName => $"JISREM.{TableDefinition.Table}";
    public string TargetTableName => $"{TableDefinition.Owner}.{TableDefinition.Table}";

    protected TableChange(TableDefinition tableDefinition, ActionType action)
    {
        TableDefinition = tableDefinition;
        Action = action;
    }

    public override string ToString() => $"{GetType().Name}::{Action.Value}";

    public virtual void AddDeclares(BlockDeclarations declare)
    {
        
    }   

    public virtual string BeforeSnapshot(Charge charge)
        => $"""
            --SNAPSHOT BEFORE
            INSERT INTO {SnapshotTableName}
            SELECT
                source_row.*,
                :cleanup_id,
                '{Action.Value}',
                '{SnapshotType.Before.Value}'
            FROM {TargetTableName} source_row
            WHERE {WherePredicate(charge)}
            ;

            """;

    public abstract string WherePredicate(Charge charge);

    public abstract string AfterSnapshot(Charge charge);

    public string LogOperation(Charge charge)
        => $"""

            JISREM.LOG
            (
                p_cleanup_id    => :CLEANUP_ID,
                p_charge_id       => '{charge.ChargeId}',
                p_step_name     => '{ChangeName}',
                p_affected_rows => v_count
            );

            """;

    protected abstract string Apply(Charge charge);

    public string ApplyChange(Charge charge)
        => $"""
           {Apply(charge)}

            v_count := SQL%ROWCOUNT;
            
           """;
        

    private string BuildConstraintName(string suffix)
    {
        return $"{TableDefinition.Table}_{suffix}";
    }

    public string CreateSnapshotTableIfMissing()
    {
        var checkConstraintName = BuildConstraintName("CK");
        var uniqueConstraintName = BuildConstraintName("UQ");
        var cleanupConstraintName = BuildConstraintName("FK");

        return $"""
                DECLARE
                    v_table_count PLS_INTEGER;
                BEGIN
                    SELECT
                        COUNT(*)
                    INTO
                        v_table_count
                    FROM
                        ALL_TABLES
                    WHERE
                        owner = 'JISREM'
                        AND table_name = '{TableDefinition.Table.ToUpperInvariant()}';

                    IF v_table_count = 0
                    THEN
                        EXECUTE IMMEDIATE
                            'CREATE TABLE {SnapshotTableName} AS 
                            SELECT * 
                            FROM {TargetTableName}
                            WHERE 1 = 0';

                        EXECUTE IMMEDIATE
                            'ALTER TABLE {SnapshotTableName} ADD 
                            ( 
                                cleanup_id NUMBER, 
                                change_action VARCHAR2(50), 
                                row_state VARCHAR2(50) 
                            )';

                        EXECUTE IMMEDIATE
                            'ALTER TABLE {SnapshotTableName} MODIFY 
                            ( 
                                cleanup_id NOT NULL, 
                                change_action NOT NULL, 
                                row_state NOT NULL 
                            )';

                        EXECUTE IMMEDIATE
                            'ALTER TABLE {SnapshotTableName} 
                            ADD CONSTRAINT {uniqueConstraintName} 
                            UNIQUE 
                            ( 
                                cleanup_id, 
                                {TableDefinition.PrimaryKeyColumn}, 
                                row_state 
                            )';

                        EXECUTE IMMEDIATE
                            'ALTER TABLE {SnapshotTableName} 
                            ADD CONSTRAINT {cleanupConstraintName} 
                            FOREIGN KEY (cleanup_id) 
                            REFERENCES JISREM.CLEANUP (cleanup_id)';
                    END IF;
                END;
                /

                """;
    }
}