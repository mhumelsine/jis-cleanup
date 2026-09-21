$ErrorActionPreference = "Stop"

$duckDb = (Get-Command duckdb -ErrorAction Stop).Source
$rootDirectory = Join-Path $HOME "Desktop/partitioned_manual"

& $duckDb -version

if ($LASTEXITCODE -ne 0) {
    throw "Unable to execute DuckDB."
}

Write-Host "Installing the Excel extension..."

& $duckDb -batch -bail -c @'
FORCE INSTALL excel;
LOAD excel;

SELECT
    version() AS duckdb_version,
    extension_name,
    loaded,
    installed
FROM duckdb_extensions()
WHERE extension_name = 'excel';
'@

if ($LASTEXITCODE -ne 0) {
    throw "Excel extension installation failed."
}

if (Test-Path $rootDirectory) {
    Write-Host "Removing previous output: $rootDirectory"
    Remove-Item $rootDirectory -Recurse -Force
}

Write-Host "Running DuckDB export..."

& $duckDb -batch -bail -c @'
FORCE INSTALL excel;
LOAD excel;

COPY (
    select
    *
    from read_xlsx('~/Desktop/remaining_manual_list.xlsx', sheet = 'Result 1', stop_at_empty = true, header = true, all_varchar = true)
)
TO '~/Desktop/partitioned_manual'
(FORMAT 'XLSX', HEADER true, PARTITION_BY (PARTITION_NUMBER));
'@

if ($LASTEXITCODE -ne 0) {
    throw "DuckDB export failed."
}

Write-Host "Applying Excel validation..."

dotnet run -- excel $rootDirectory

if ($LASTEXITCODE -ne 0) {
    throw "Excel validation failed."
}

Write-Host "Completed successfully."