# JIS Cleanup Script Generator

Use this project to generate repeatable Oracle cleanup scripts. Each cleanup has its own directory containing the cleanup class, source query, and generated data and SQL files.

## Quick Start

- [ ] Configure a `.env` file at the root of you repository.  This is not checked into source control for security.

```
ORACLE_USERNAME=TODO_SOMEUSER
ORACLE_PASSWORD=TODO_SOMEPASSWORD
ORACLE_HOST=TODO_SOMEHOST
```

- [ ] `pwsh New-Cleanup.ps1 "CleanupName" to create a new cleanup `

```powershell
pwsh New-Cleanup.ps1 "03_DocketsWithStatusChanges" 
```

- [ ] Populate the query.sql file with the query you'd like to use in the newly created directory: `Cleanups/
[Cleanup Name]`

- [ ] Execute the build script to compile and emit the batch of sql files
```powershell
pwsh Build-Cleanup.ps1 "03_DocketsWithStatusChanges" 
```

## What It Does

The generator:

1. Runs the cleanup's `query.sql` against Oracle.
2. Writes the query results to a timestamped CSV file.
3. Loads the extracted records.
4. Builds the configured cleanup scripts.
5. Writes the generated SQL files to the cleanup directory.

The generated Oracle scripts:

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
- PowerShell
- Oracle connection settings in the project's `.env` file

`Build-Cleanup.ps1` loads the values from `.env` into the local process environment before running the generator. The required variable names are determined by `OracleCsvDataExtractor`.

## Cleanup Structure

Each cleanup is stored in its own directory:

```text
Cleanups/
└── CleanupName/
    ├── Cleanup_CleanupName.cs
    ├── query.sql
    ├── scripts/
    └── yyyyMMdd_hhmmss_data.csv
```

The `scripts` directory is created for cleanup-specific SQL or supporting scripts. Generated files are written under the cleanup path by `CleanupBase.Build`.

The cleanup name passed on the command line must match both:

- The cleanup directory: `Cleanups/CleanupName`
- The class suffix: `JisCleanup.Cleanups.Cleanup_CleanupName`

## Create a Cleanup

Run:

```powershell
.\New-Cleanup.ps1 "CleanupName"
```

The script creates:

```text
Cleanups/CleanupName/
├── Cleanup_CleanupName.cs
├── query.sql
└── scripts/
```

If the cleanup directory already exists, the script exits without changing it.

The generated class is a starting point:

```csharp
using JisCleanup.Changes;
using JisCleanup.TableChanges;
using JisCleanup.Validations;

namespace JisCleanup.Cleanups;

public class Cleanup_CleanupName : CleanupBase
{
    public Cleanup_CleanupName()
    {
        Metadata = new CleanupMetadata
        {
            Name = GetType().Name,
            Description = "TODO",
            RequestedBy = "JIS"
        };

        Validations =
        [
            // TODO
        ];

        Changes =
        [
            // TODO
            new InsertCleanupDocketEntry()
        ];
    }
}
```

Update the metadata, validators, and changes for the cleanup before building it.

The order of `Changes` is the execution order. Put dependent changes after the changes that produce the rows or snapshots they require.

## Define the Source Query

Add the Oracle query used to identify the records to:

```text
Cleanups/CleanupName/query.sql
```

When the cleanup is built, the query results are written to:

```text
Cleanups/CleanupName/yyyyMMdd_hhmmss_data.csv
```

The same timestamp is passed to `CleanupBase.Build` for the generated cleanup output.

## Build a Cleanup

Run:

```powershell
.\Build-Cleanup.ps1 "CleanupName"
```

`Build-Cleanup.ps1`:

1. Requires the cleanup name as a positional argument.
2. Loads local environment variables from `.env`.
3. Runs `dotnet run -- "CleanupName"`.

You can also run the generator directly if the required environment variables are already set:

```powershell
dotnet run -- "CleanupName"
```

The application resolves the cleanup type using:

```csharp
Type.GetType($"JisCleanup.Cleanups.Cleanup_{cleanupName}")
```

For example:

```powershell
.\Build-Cleanup.ps1 "01_GroceryStoreRun"
```

This resolves:

```text
JisCleanup.Cleanups.Cleanup_01_GroceryStoreRun
```

and uses:

```text
Cleanups/01_GroceryStoreRun/query.sql
```

A successful build ends with:

```text
Build Success
```

## Input Loading

`ILoader<TRecord>` handles input loading:

```csharp
public interface ILoader<out TRecord>
{
    IEnumerable<TRecord> Load();
}
```

`CsvChargeLoader` loads the timestamped CSV created by `OracleCsvDataExtractor`.

The loader expects a header followed by seven columns in this order:

```text
CJIS SPN,CJIS Case Number,Case Defendant ID,Charge ID,Status,Location,Bond Amount
```

The CSV loader expects exactly seven comma-separated values. It does not handle quoted values containing commas.

## Validators

Add validators to the cleanup's `Validations` collection. They run before the changes for each charge.

A validator collects the current database state and checks whether the charge is safe to process. Add any required PL/SQL variables or types through `Declares`.

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

Every table change receives a `TableDefinition`:

```csharp
new TableDefinition("JISJDW", "CASE_DEFENDANT", "CASE_DEFENDANT_ID")
```

That maps:

```text
Source:      JISJDW.CASE_DEFENDANT
Snapshot:    JISREM.CASE_DEFENDANT
Primary key: CASE_DEFENDANT_ID
```

`TableChange` handles the common work:

- Builds source and snapshot table names.
- Generates snapshot-table DDL when the table does not exist.
- Captures the default before snapshot.
- Runs the change.
- Stores `SQL%ROWCOUNT` in `v_count`.
- Logs the operation.

### Delete Change

Derive from `DeleteTableChange` and implement `WherePredicate`:

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

A predicate can use snapshots created by earlier changes. If a predicate depends on an earlier snapshot, keep the changes in the required order.

### Update Change

Derive from `UpdateChange` and implement `WherePredicate` and `Apply`:

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

### Insert Change

Derive from `InsertTableChange`, pass the Oracle sequence name, and implement `Apply`:

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

`CaseLoopActivity`, `DeclaresActivity`, and `EndCaseLoopActivity` contain an alternate queue-driven case loop. They are not called by the current compile path, which emits one `ChargeBlock` per loaded charge.

## What the Generated Script Does

Each SQL file:

- Creates missing cleanup tables and sequences in `JISREM`.
- Creates the logging procedure.
- Creates missing snapshot tables for the configured changes.
- Registers the cleanup and its queued charges.
- Starts the transaction.
- Processes each charge:
   - Creates a savepoint.
   - Runs the validators.
   - Captures the required before snapshots.
   - Applies the configured changes in order.
   - Captures the required after snapshots.
   - Logs affected-row counts.
   - Rolls back and logs the charge if that charge fails.
- Commits the cleanup.

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

Generated SQL filenames follow the format defined by `CleanupBase`. Review the emitted filenames in the console after each build.

## Before You Execute a Generated Script

Check the generated SQL, not just the C# configuration.

- Verify the cleanup name, description, and requestor.
- Verify the source query and extracted row count.
- Verify validation predicates and cutoff values.
- Verify change order.
- Verify table owners, table names, primary keys, and sequences.
- Verify each `WherePredicate` selects only the intended rows.
- Verify insert changes use `v_inserted_id` correctly.
- Verify snapshot tables still match their `JISJDW` source tables.
- Test every generated script outside production first.

## Cleanup Checklist

- The docket entry is correct for the cleanup being applied, including date and language.
- The cleanup name and description accurately describe the scenario.
- `query.sql` selects only the intended records.
- The generated CSV contains the expected records and columns.
- Validators fail safely when a record should not be changed.
- Changes are ordered correctly.
- Generated SQL has been reviewed and tested before production execution.
