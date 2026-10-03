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

- [ ] Review the output under `Cleanups/03_DocketsWithStatusChanges/scripts/<timestamp>/`

- [ ] Run the generated scripts against Oracle
```powershell
pwsh Run-Cleanup.ps1 -CleanupTimestamp "<timestamp>" -CleanupNames "03_DocketsWithStatusChanges"
```

## Runbook: Creating a New Cleanup

Follow these steps end to end to produce and run a cleanup.

1. **Configure credentials.** Create a `.env` file at the repository root (not checked in):

   ```text
   ORACLE_USERNAME=TODO_SOMEUSER
   ORACLE_PASSWORD=TODO_SOMEPASSWORD
   ORACLE_HOST=TODO_SOMEHOST
   ```

2. **Scaffold the cleanup.**

   ```powershell
   pwsh New-Cleanup.ps1 "04_MyCleanup"
   ```

   This creates `Cleanups/04_MyCleanup/` with `Cleanup_04_MyCleanup.cs`, an empty `query.sql`, and a `scripts/` folder. It exits without changes if the directory already exists.

3. **Write the source query.** Add the Oracle query that identifies the records to `Cleanups/04_MyCleanup/query.sql`. It must return the seven CSV columns: `CJIS_SPN,CJIS_CASE_NUMBER,CASE_DEFENDANT_ID,CHARGE_ID,OLD_STATUS,OLD_LOCATION,OLD_BOND_AMT`.

4. **Implement the cleanup class.** Edit `Cleanups/04_MyCleanup/Cleanup_04_MyCleanup.cs`:
   - Set `Metadata.Description`.
   - Add validators to `Validations` (run before changes; a failing validator skips the charge).
   - Add changes to `Changes` in execution order. Reuse existing changes from `Changes/` where possible.

5. **Build the cleanup.**

   ```powershell
   pwsh Build-Cleanup.ps1 "04_MyCleanup"
   ```

   The build runs `query.sql` against Oracle, writes `Cleanups/04_MyCleanup/yyyyMMdd_hhmmss_data.csv`, and emits SQL to `Cleanups/04_MyCleanup/scripts/yyyyMMdd_hhmmss/`. It ends with `Build Success`.

6. **Review the output.** Check the generated CSV row count and read the generated SQL files. Confirm names, predicates, change order, and snapshot tables before executing.

7. **Run the cleanup.** Use the timestamp from the build output:

   ```powershell
   pwsh Run-Cleanup.ps1 -CleanupTimestamp "yyyyMMdd_hhmmss" -CleanupNames "04_MyCleanup"
   ```

   This executes every `.sql` file in `Cleanups/04_MyCleanup/scripts/yyyyMMdd_hhmmss/` against Oracle with SQLcl and rolls back on error.

8. **Verify in Oracle.** Check the `JISREM.CLEANUP_LOG` entries and the `JISREM` snapshot tables for the cleanup partition.

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
- SQLcl (Oracle command-line client) for `Run-Cleanup.ps1`, expected at `/opt/sqlcl/bin/sql`

`Build-Cleanup.ps1` loads the values from `.env` into the local process environment before running the generator. The required variable names are determined by `OracleFacade`.

## Cleanup Structure

Each cleanup is stored in its own directory:

```text
Cleanups/
└── CleanupName/
    ├── Cleanup_CleanupName.cs
    ├── query.sql
    ├── scripts/
    │   └── yyyyMMdd_hhmmss/        # generated SQL, one folder per build
    │       ├── Cleanup_CleanupName_1.sql
    │       └── ...
    └── yyyyMMdd_hhmmss_data.csv    # extracted query results
```

The `scripts` directory is created for cleanup-specific SQL or supporting scripts. Generated files are written to `Cleanups/CleanupName/scripts/<timestamp>/` by `CleanupBase.Build`.

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

1. Requires one or more cleanup names as positional arguments.
2. Loads local environment variables from `.env`.
3. Runs `dotnet run -- "build" "CleanupName"` (for each name).

You can also run the generator directly if the required environment variables are already set:

```powershell
dotnet run -- "build" "CleanupName"
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

The loader expects a header followed by seven comma-separated columns:

```text
CJIS_SPN,CJIS_CASE_NUMBER,CASE_DEFENDANT_ID,CHARGE_ID,OLD_STATUS,OLD_LOCATION,OLD_BOND_AMT
```

The CSV loader expects exactly seven comma-separated values per row. It does not handle quoted values containing commas.

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
- `ReportCleanupAgentsRegistered`: reports the agents/changes registered for the cleanup.
- `BeginTransactionActivity`: starts transaction processing.
- `ValidationsActivity`: runs the validators for one charge.
- `ApplyChangesActivity`: applies the changes for one charge.
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
private List<CleanupBatch<TRecord>> Partition<TRecord>(ILoader<TRecord> loader)
    => loader.Load()
        .Chunk(PartitionSize)
        .Select((x, index) => new CleanupBatch<TRecord>
        {
            OutputFileName = $"{Metadata.Name}_{index + 1}.sql",
            Items = x.ToHashSet(),
            Metadata = Metadata with { Name = $"{timestamp}_{Metadata.Name}_{index + 1}" }
        })
        .ToList();
```

Generated SQL files are written to `Cleanups/CleanupName/scripts/<timestamp>/` and named `<CleanupName>_<partitionIndex>.sql`. The console lists each emitted file after a build.

## Run a Generated Cleanup

```powershell
pwsh Run-Cleanup.ps1 -CleanupTimestamp "yyyyMMdd_hhmmss" -CleanupNames "CleanupName"
```

`Run-Cleanup.ps1`:

1. Requires the build timestamp and one or more cleanup names.
2. Loads local environment variables from `.env`.
3. Looks for `Cleanups/<name>/scripts/<timestamp>/*.sql` and exits if the directory does not exist.
4. Executes the scripts in that folder (newest first) with SQLcl, stopping on the first error and rolling back on failure.

The connection string is built from `ORACLE_USERNAME`, `ORACLE_PASSWORD`, and `ORACLE_HOST` in `.env`, targeting the `JISPROD` service on port 1521.

## Manual Cleanups

A cleanup can skip the Oracle extraction step by adding a `ManualCleanup` attribute with the name of a data file already in the cleanup directory:

```csharp
[ManualCleanup("data.csv")]
public class Cleanup_04_Manual_TechnicalReview : CleanupBase { ... }
```

The build then loads `data.csv` directly instead of running `query.sql` against Oracle. `Process-Manual.ps1` prepares and validates manual workbooks via `dotnet run -- excel <directory>`.

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

- [x] The docket entry is correct for the cleanup being applied, including date and language.
- [x] The cleanup name and description accurately describe the scenario.
- [x] `query.sql` selects only the intended records.
- [x] The generated CSV contains the expected records and columns.
- [x] Validators fail safely when a record should not be changed.
- [x] Changes are ordered correctly.
- [x] Generated SQL has been reviewed and tested before production execution.

# DUCKDB Query for Targeted Cleanup
```sql
select distinct
    CJIS_SPN,
    (regexp_extract(CJIS_CASE_NUMBER, '(\d{4}\w{2}\d+\w).+', ['case_number'])).case_number "CJIS Case #",
    atty_judge.*
from '~/repos/JisCleanup/Cleanups/court_admin_order/0*.json' case_cleanup
left join '~/repos/JisCleanup/Cleanups/court_admin_order/attorney_assignments.json' atty_judge
on (regexp_extract(case_cleanup.CJIS_CASE_NUMBER, '(\d{4}\w{2}\d+\w).+', ['case_number'])).case_number = atty_judge."CASE NUMBER"
order by CJIS_SPN, CJIS_CASE_NUMBER;
```

# Find Last Attorney and Judge Assignments
```sql

with case_attorney as (
    select
        row_number() over (partition by d.CJIS_CASE_NUMBER order by rp.DATE_ASSIGNED desc) most_recent_attorney
        ,rp.DEFENSE_ATTORNEY_TYPE
        ,a.LAST_NAME
        ,a.FIRST_NAME
        ,d.CJIS_CASE_NUMBER
    from JISJDW.case_related_person rp
    left join JISJDW.CASE_DEFENDANT d
    on rp.CASE_DEFENDANT_ID = d.CASE_DEFENDANT_ID
    left join JISJDW.ATTORNEY a
    on rp.DEFENSE_ATTORNEY_ID = a.FLORIDA_BAR_ID
    where rp.PERSON_CODE IN ('CA', 'PD', 'DA')
    order by d.CJIS_CASE_NUMBER desc
),
judge_assignment as (
    select
        row_number() over (partition by d.CJIS_CASE_NUMBER order by rp.DATE_ASSIGNED desc) most_recent_judge
        ,d.CJIS_SPN
        ,d.CJIS_CASE_NUMBER
        ,j.LAST_NAME
        ,j.FIRST_NAME
        ,rp.DATE_ASSIGNED
        ,d.DIVISION
    from JISJDW.CASE_RELATED_PERSON rp
    inner join JISJDW.CASE_DEFENDANT d
    on rp.CASE_DEFENDANT_ID = d.CASE_DEFENDANT_ID
    inner join JISJDW.JUDGE j
    on rp.JUDGE_ID  = j.JUDGE_ID
  --WHERE rp.PERSON_CODE = 'JU' --TODO:  Most recent activity's judge vs. most recent judge assignment?
),
data_source as (
    select
        c.SPN_ID SPN
        ,REGEXP_SUBSTR(c.CASE_ID, '(\d{4}\w{2}\d+\w{1}).+', 1,1,null,1) "CASE NUMBER"
        ,atty.LAST_NAME "ATTORNEY LAST NAME"
        ,atty.FIRST_NAME "ATTORNEY FIRST NAME"
        ,judge.DIVISION
        ,judge.LAST_NAME "JUDGE LAST NAME"
        ,judge.FIRST_NAME "JUDGE FIRST NAME"
        ,d.LAST_NAME "DEFENDANT LAST NAME"
        ,d.FIRST_NAME "DEFENDANT FIRST NAME"
    from (
        select CHARGE_ID,
           CJIS_SPN SPN_ID,
           CJIS_CASE_NUMBER CASE_ID
        from JISJDW.V_PNX2JIS_BAD_DKT
    ) c
    left join case_attorney atty
    on atty.CJIS_CASE_NUMBER = REGEXP_SUBSTR(c.CASE_ID, '(\d{4}\w{2}\d+\w{1}).+', 1,1,null,1) --c.CASE_ID
    left join judge_assignment judge
    on judge.CJIS_CASE_NUMBER = REGEXP_SUBSTR(c.CASE_ID, '(\d{4}\w{2}\d+\w{1}).+', 1,1,null,1) --c.CASE_ID
    left join JISJDW.DEFENDANT d
    on d.CJIS_SPN = c.SPN_ID
    where atty.most_recent_attorney = 1
    and judge.most_recent_judge = 1
)
select distinct
    DIVISION,
    "JUDGE LAST NAME" || ', ' || "JUDGE FIRST NAME" "JUDGE",
    SPN,
    "DEFENDANT LAST NAME",
    "DEFENDANT FIRST NAME",
    "CASE NUMBER",
    "ATTORNEY LAST NAME" || ', ' || "ATTORNEY FIRST NAME" "LAST DEFENSE ATTORNEY"

from data_source
order by SPN, "CASE NUMBER";
```

# Updated View on 10/02:  V_PNX2JIS_BAD_DKT_v2

```sql
create or replace view JISJDW.V_PNX2JIS_BAD_DKT_v2 as
    SELECT
        de.cjis_spn,
        de.last_name,
        de.first_name,
        ch.cjis_case_number,
        ch.case_defendant_id,
        d.charge_id,
        ch.charge_literal,
        ch.charge_count,
        d.cjis_docket_id,
        d.docket_seq,
        d.docket_code,
        dc.docket_literal,
        d.docket_free_text,
        d.docket_date,
        d.received_date,
        D.CREATE_USER_ID
    from JISJDW.cjis_docket d

    left join JISJDW.CJIS_DOCKET_CODE dc
    on d.DOCKET_CODE = dc.DOCKET_CODE

    inner join JISJDW.charge ch on ch.charge_id = d.charge_id

    left join JISJDW.DEFENDANT de
    on de.CJIS_SPN = ch.CJIS_SPN

    left join JISJDW.user_list ul on d.create_user_id = ul.user_id

    where d.CREATE_DATE_TIME >= '18-AUG-2026'
    and d.CREATE_DATE_TIME < '31-AUG-2026'
    and (docket_date - received_date) < 0
    and d.CREATE_USER_ID IN ('SYSTEMA', 'PNX2JIS');
/
```