# JIS Cleanup Script Generator

Use this project to generate repeatable Oracle cleanup scripts. For each cleanup, add one `Cleanup` class, configure its validators and changes, add the matching CSV, and run the generator.

## What It Does

The generator builds Oracle scripts that:

- Validate each charge before changing it.
- Apply the configured inserts, updates, and deletes in order.
- Save row snapshots to `JISREM` before and after each change.
- Log the cleanup, each operation, affected-row counts, and failures.
- Roll back only the current charge when that charge fails.
- Commit the script when processing finishes.

Each snapshot table mirrors its source table in `JISJDW` and adds:

| Column | Values |
|---|---|
| `cleanup_id` | Unique ID for the generated cleanup partition |
| `change_action` | `INSERT`, `UPDATE`, or `DELETE` |
| `row_state` | `BEFORE` or `AFTER` |

Snapshots work like this:

| Change | Before | After |
|---|---:|---:|
| Insert | No | Yes |
| Update | Yes | Yes |
| Delete | Yes | No |

## Requirements

- .NET 10 SDK

## Add a Cleanup

Create one class derived from `Cleanup` for each cleanup scenario.

```csharp
namespace JisCleanup.Cleanups;

public class Cleanup_01_GroceryStoreRun : Cleanup
{
    public Cleanup_01_GroceryStoreRun()
    {
        Metadata = new CleanupMetadata
        {
            Name = GetType().Name,
            Description = "Grocery store run; Initial cleanup of around 395 cases with only invalid system activity",
            RequestedBy = "JIS",
            RunNumber = 0
        };

        Validations =
        [
            new NoHumanActivity()
        ];

        Changes =
        [
            new RestoreStatusLocationBondAmount(),
            new CjisDocketDelete(),
            new FaChargeDelete(),
            new CourtCalendarDelete(),
            new FirstAppearanceDelete(),
            new CustodyStatusDelete(),
            new ReleaseBondDelete(),
            new InsertCleanupDocketEntry()
        ];
    }
}
```

The order of `Changes` is the execution order. Put dependent changes after the changes that produce the rows or snapshots they need.

## Input

`ILoader<TRecord>` handles input loading:

```csharp
public interface ILoader<out TRecord>
{
    IEnumerable<TRecord> Load();
}
```

`CsvChargeLoader` is currently the only loader. It reads a header followed by seven columns in this order:

```text
CJIS SPN,CJIS Case Number,Case Defendant ID,Charge ID,Status,Location,Bond Amount
```

Name the CSV after the cleanup class and put both files in `Cleanups`:

```text
Cleanup_01_GroceryStoreRun.cs
Cleanup_01_GroceryStoreRun.csv
```

The CSV loader expects exactly seven comma-separated values. It does not handle quoted values that contain commas.

## Validators

Add validators to the scenario's `Validations` collection. They run before the changes for each charge.

A validator collects the current database state and checks whether the charge is safe to process. Add any PL/SQL variables or types through `Declares`.

`NoHumanActivity` checks the audit trail for non-system activity after the configured cutoff:

```csharp
public class NoHumanActivity : Validator
{
    protected override string Collect(Charge charge)
        => $"""
            SELECT COUNT(*)
            INTO v_count
            FROM JISJDW.audit_trail
            WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
            AND cjis_case_number = '{charge.CjisCaseNumber}'
            AND
            (
                activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS')
                OR activity_user_id IS NULL
            );
            """;

    protected override string Check()
        => ExactlyZero("Human activity found in Audit Trail");

    public override void Declares(BlockDeclarations declarations)
    {
    }
}
```

## Changes

Every change derives from `TableChange` and receives a `TableDefinition`:

```csharp
new TableDefinition("JISJDW", "CASE_DEFENDANT", "CASE_DEFENDANT_ID")
```

That maps:

```text
Source:   JISJDW.CASE_DEFENDANT
Snapshot: JISREM.CASE_DEFENDANT
Primary key: CASE_DEFENDANT_ID
```

`TableChange` handles the common work:

- Builds source and snapshot table names.
- Generates snapshot-table DDL when the table does not exist.
- Captures the default before snapshot.
- Runs the change.
- Stores `SQL%ROWCOUNT` in `v_count`.
- Logs the operation.

### DeleteChange

Derive from `DeleteTableChange` and implement `WherePredicate`.

```csharp
public sealed class CaseDefendantDelete : DeleteTableChange
{
    public CaseDefendantDelete()
        : base(new TableDefinition(
            "JISJDW",
            "CASE_DEFENDANT",
            "CASE_DEFENDANT_ID"))
    {
    }

    public override string WherePredicate(Charge charge)
        => $"source_row.CASE_DEFENDANT_ID = {charge.CaseDefendantId}";
}
```

The generated SQL snapshots the matching rows as `BEFORE`, deletes them, records the affected-row count, and does not create an `AFTER` snapshot.

A predicate can also use snapshots created by earlier changes. `ArrestDelete` takes that approach to find related `ARREST_ID` values. If a predicate depends on an earlier snapshot, keep those changes in the required order.

### UpdateChange

Derive from `UpdateChange`. Implement `WherePredicate` and `Apply`.

```csharp
public sealed class RestoreExample : UpdateChange
{
    public RestoreExample()
        : base(
            new TableDefinition("JISJDW", "CHARGE", "CHARGE_ID"),
            ActionType.Updated)
    {
    }

    public override string WherePredicate(Charge charge)
        => $"source_row.CHARGE_ID = {charge.ChargeId}";

    protected override string Apply(Charge charge)
        => $"""
            UPDATE JISJDW.CHARGE source_row
            SET source_row.STATUS = '{charge.Status}'
            WHERE {WherePredicate(charge)};
            """;
}
```

The generated SQL captures `BEFORE`, runs the update, captures `AFTER`, and logs the affected-row count.

### InsertChange

Derive from `InsertTableChange`, pass the Oracle sequence name, and implement `Apply`.

```csharp
public sealed class InsertCleanupDocketEntry : InsertTableChange
{
    public InsertCleanupDocketEntry()
        : base(
            new TableDefinition("JISJDW", "CJIS_DOCKET", "CJIS_DOCKET_ID"),
            "JISJDW.CJIS_DOCKET_SEQ")
    {
    }

    protected override string Apply(Charge charge)
        => $"""
            INSERT INTO JISJDW.CJIS_DOCKET
            (
                CJIS_DOCKET_ID,
                CHARGE_ID
            )
            VALUES
            (
                v_inserted_id,
                {charge.ChargeId}
            );
            """;
}
```

`InsertTableChange` assigns the sequence's `NEXTVAL` to `v_inserted_id`. Use that variable as the inserted primary key. The generated SQL inserts the row, captures it as `AFTER`, and does not create a `BEFORE` snapshot.

`InsertTableChange.WherePredicate` currently targets `CJIS_DOCKET_ID`. If another insert change targets a different primary-key column, override the predicate or generalize the base implementation first.

## Activities

Activities append PL/SQL to the output through `IActivity`:

```csharp
public interface IActivity
{
    void Build(StringBuilder builder);
}
```

The main activities are:

- `CreateLoggingInfrastructureActivity`: creates missing cleanup tables and sequences.
- `LoggingProcedureActivity`: creates the logging procedure.
- `EnsureSnapshotTableExistActivity`: creates missing snapshot tables.
- `InitializeCleanupActivity`: registers the cleanup and queues its input records.
- `BeginTransactionActivity`: starts transaction processing.
- `ChargeBlock`: runs validation and changes for one charge inside a savepoint.
- `CommitChangesActivity`: commits a normal run or rolls back a what-if run.

`ChargeBlock` catches unhandled errors for one charge, rolls back to `before_record`, logs the error, and marks that queue entry as `PROCESSING_FAILED`. Processing can then continue with the next generated charge block.

`CaseLoopActivity`, `DeclaresActivity`, and `EndCaseLoopActivity` contain an alternate queue-driven case loop. They are not called by the current `Cleanup.Compile` path, which emits one `ChargeBlock` per loaded charge.

## Run It

Select the cleanup in `Program.cs`:

```csharp
var cleanup = new Cleanup_01_GroceryStoreRun();
var inputFilePath = Path.Combine(
    PathHelper.GetCleanupPath(),
    $"{cleanup.GetType().Name}.csv");

var writer = new CleanupWriter();
var loader = new CsvChargeLoader(inputFilePath);

cleanup.Build(writer, loader);
Console.WriteLine("Build Success");
```

Run a Debug build:

```bash
dotnet run
```

Run a Release build:

```bash
dotnet run --configuration Release
```

Before generating the next run, update `Metadata.RunNumber`. The filename uses `RunNumber + 1`.

## Output

Input and output files are resolved from the `Cleanups` directory. `PathHelper` currently resolves that directory as `../../../Cleanups` from the build output directory.

Generated filenames follow this format:

```text
{CleanupName}_Run{RunNumber + 1}_Partition{PartitionNumber}.sql
```

For example:

```text
Cleanup_01_GroceryStoreRun_Run1_Partition1.sql
Cleanup_01_GroceryStoreRun_Run1_Partition2.sql
```

Each partition gets its own GUID-based `cleanup_id`.

The generator writes each filename to the console:

```text
Emitted: Cleanup_01_GroceryStoreRun_Run1_Partition1.sql
```

A successful run ends with:

```text
Build Success
```

## What the Generated Script Does

Each SQL file:

1. Creates missing cleanup tables and sequences in `JISREM`.
2. Creates the logging procedure.
3. Creates missing snapshot tables for the configured changes.
4. Registers the cleanup and its queued charges.
5. Starts the transaction.
6. Processes each charge:
   1. Creates a savepoint.
   2. Runs the validators.
   3. Captures the required before snapshots.
   4. Applies the configured changes in order.
   5. Captures the required after snapshots.
   6. Logs affected-row counts.
   7. Rolls back and logs the charge if that charge fails.
7. Commits the cleanup.

Placeholder resolution currently sets:

```text
__CLEANUP_ID__ = new GUID for the partition
__WHAT_IF__    = 0
```

The logging setup creates these objects when they do not exist:

```text
JISREM.CLEANUP
JISREM.CLEANUP_SEQ
JISREM.CLEANUP_CASE_QUEUE
JISREM.CLEANUP_LOG
JISREM.CLEANUP_LOG_SEQ
```

## Partitioning

The configured partition size is 100 charges.

```csharp
private List<CleanupBatch<TRecord>> Partition<TRecord>(
    ILoader<TRecord> loader)
{
    return loader
        .Load()
        .Distinct()
        .Chunk(PartitionSize)
        .Select((items, index) => new CleanupBatch<TRecord>
        {
            OutputFileName =
                $"{Metadata.Name}_Run{Metadata.RunNumber + 1}_Partition{index + 1}.sql",
            Items = items.ToHashSet(),
            Metadata = Metadata
        })
        .ToList();
}
```

## Before You Execute a Generated Script

Check the generated SQL, not just the C# configuration.

- Verify the cleanup name, description, requestor, and run number.
- Verify the input CSV and row count.
- Verify validation predicates and cutoff values.
- Verify change order.
- Verify table owners, table names, primary keys, and sequences.
- Verify each `WherePredicate` selects only the intended rows.
- Verify insert changes use `v_inserted_id` correctly.
- Verify snapshot tables still match their `JISJDW` source tables.
- Test every partition outside production first.

# Cleanup Checklist

- [ ] The docket entry is correct (date and language) for the cleanup being applied
- [ ] The cleanup name and description accurately describe the scenario
- [ ] 