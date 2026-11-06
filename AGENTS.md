# AGENTS.md

.NET 10 console app that compiles Oracle "cleanup" definitions into reviewable, runnable SQL scripts.
Source of truth is the code, not the README; `README.md` documents the cleanup author workflow.

## Commands

Run from the repo root.

| Command | Notes |
|---|---|
| `dotnet build` | The only automated check. No test project, no CI, no linter/formatter config. |
| `pwsh New-Cleanup.ps1 "<Name>"` | Scaffolds `Cleanups/<Name>/`. Exits 1 if the directory already exists. |
| `pwsh Build-Cleanup.ps1 "<Name>" ["<Name2>"]` | Extracts from Oracle and emits SQL. Needs `.env` in the CWD **and** DB access. |
| `pwsh Run-Cleanup.ps1 -CleanupTimestamp "<yyyyMMdd_hhmmss>" -CleanupNames "<Name>"` | Executes emitted SQL via SQLcl. |
| `dotnet run -- "build" "<Name>"` | Same as `Build-Cleanup.ps1` but skips the `.env` load; env vars must already be set. |
| `dotnet run -- "excel" <dir>` | Second CLI verb. Validates reviewer workbooks (used by `Process-Manual.ps1`). |

`Program.cs` switches on the first argument; `build` and `excel` are the only verbs. `dotnet run -- "<Name>"` (no verb) hits `default:` and returns exit code 1 **without any output** — that silent failure is a common mistake.

## Hard wiring constraints

- **Name triple.** Directory `Cleanups/<Name>`, file `Cleanup_<Name>.cs`, class `Cleanup_<Name>` in namespace `JisCleanup.Cleanups`. `ScriptBuilder` resolves it with `Type.GetType($"JisCleanup.Cleanups.Cleanup_{cleanupName}")` — an exact string match with no fallback, so a folder rename without a class rename fails with "Could not resolve type".
- **Path resolution is relative to the build output.** `PathHelper.GetCleanupPath` resolves `../../../Cleanups/<name>` from `AppDomain.CurrentDomain.BaseDirectory`, so the app only finds cleanup folders when run from `bin/Debug/net10.0` (i.e. `dotnet run` in the repo). A published/copied exe will not find them.
- **The csproj copies `Cleanups/**/*` to the output dir** (`Content`/`PreserveNewest`), so generated CSVs and emitted scripts are copied on every build. Don't check those artifacts in.

## Data contract

- `CsvChargeLoader` skips row 1, splits on `,`, and **requires exactly 7 fields per row** (throws `FileLoadException` otherwise). Quoted values containing commas break it.
- Mapping is **positional, not by header name**: `CJIS_SPN, CJIS_CASE_NUMBER, CASE_DEFENDANT_ID, CHARGE_ID, OLD_STATUS, OLD_LOCATION, OLD_BOND_AMT` → `CjisSpn, CjisCaseNumber, CaseDefendantId, ChargeId, Status, Location, BondAmount`. The header line is whatever column aliases the Oracle query returns; the loader ignores it.
- `OracleFacade` writes the CSV header from the cursor's column names, so the query's first selected column is the SPN and the seventh is the bond amount.

## Environment

- `.env` is gitignored and required by `Build-Cleanup.ps1` / `Run-Cleanup.ps1`; both do `Get-Content .env` from the **current directory** and fail hard if it is missing. Keys: `ORACLE_USERNAME`, `ORACLE_PASSWORD`, `ORACLE_HOST`.
- `OracleFacade` appends `:1521/JISPROD` to `ORACLE_HOST` — pass a hostname only, not a host:port.
- `Run-Cleanup.ps1` hardcodes the SQLcl path `/opt/sqlcl/bin/sql` and the `JISPROD` service. Changing the target means editing the script.
- **A cleanup cannot be built offline.** `ScriptBuilder` always runs `query.sql` against Oracle and writes the CSV. The only exception is a cleanup class marked `[ManualCleanup("data.csv")]`, which loads that file from the cleanup folder instead.

## How the SQL is generated

- `CleanupBase.Compile` emits infra DDL, then **one self-contained `ChargeBlock` PL/SQL block per charge** (not a runtime loop), then the commit. Each block declares `v_is_valid`, `v_validation_error`, `v_count`, `v_error_message`, `v_inserted_id` and commits at the end because `__WHAT_IF__` is hardcoded to `0` — there is no wired-up dry-run mode.
- `__CLEANUP_ID__` becomes a fresh GUID per emitted file, so files are not idempotent across runs.
- `Changes` array order is execution order; a change's `WherePredicate` may depend on rows or snapshots produced by earlier changes.
- `TableChange` emits the snapshot DDL **only if `JISREM.<TABLE>` is missing**. A stale snapshot table from an earlier run is reused as-is — its columns must still match the source table.
- Partition size is 100 charges. Output: `Cleanups/<Name>/scripts/<timestamp>/<CleanupName>_<n>.sql`, where the timestamp (`yyyyMMdd_hhmmss`) is generated once per `build` invocation and shared by every cleanup named in that invocation.
- `InsertTableChange` assigns `v_inserted_id := <sequence>.NEXTVAL` and hardcodes its `WherePredicate` to `CJIS_DOCKET_ID = v_inserted_id`; insert changes must use `v_inserted_id` as the inserted PK.
- `Validator` subclasses implement `Collect` (a `SELECT COUNT(*) INTO v_count`), `Check` (`ExactlyZero` / `ExactlyOne` / `NotZero`) and `Declares`. A failed validator sets `v_is_valid := 0`, logs, marks the queue row `VALIDATION_FAILED` and `RETURN`s that charge only.

## Where things live

| Path | Contents |
|---|---|
| root `*.cs` | Runtime plumbing: `Program`, `ScriptBuilder`, `OracleFacade`, `Loaders`, `Charge`, `PathHelper`, `LogEmitter`. |
| `Changes/` | Table-change primitives. Note the folder holds **three** namespaces: `JisCleanup` (base classes + most concrete changes), `JisCleanup.Changes` (`RestoreStatusLocation*`), `JisCleanup.TableChanges` (`InsertCleanupDocketEntry*`). The `New-Cleanup.ps1` template imports all three. |
| `Validations/` | `IValidation`, `Validator` base class, concrete validators. |
| `Activities/` | SQL emission pipeline used by `CleanupBase.Compile`. |
| `Cleanups/<Name>/` | One cleanup per folder: class, `query.sql`, `scripts/`, generated `*_data.csv`. |

## Verification

- There is no automated test suite. `dotnet build` (0 warnings expected) plus reading the emitted SQL is the workflow. A build that succeeds is not a correct cleanup — read the generated `.sql` and the extracted CSV.
- `JISJDW_AUDIT_TRAIL_JIS992_TEST.sql` is a manual fixture that inserts synthetic human activity into `JISJDW.AUDIT_TRAIL`; run it against a non-production DB to exercise the "human activity" validators.
- Generated SQL mutates production-like Oracle schemas and commits per charge. Never run `Run-Cleanup.ps1` against a database you have not been asked to touch.
