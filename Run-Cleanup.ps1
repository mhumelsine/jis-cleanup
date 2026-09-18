param(
    [Parameter(Mandatory = $true, HelpMessage = "Enter the cleanup timestamp.")]
    [string]$CleanupTimestamp,
        
    [Parameter(Mandatory = $true, HelpMessage = "Enter the cleanup name.")]
    [string[]]$CleanupNames
)

$sql = "/opt/sqlcl/bin/sql"

#set local env vars
Get-Content .env | ForEach-Object {
    $k, $v = $_ -split '=', 2
    [System.Environment]::SetEnvironmentVariable($k.Trim(), $v.Trim())

}

$connection = "$($env:ORACLE_USERNAME)/$($env:ORACLE_PASSWORD)@$($env:ORACLE_HOST):1521/JISPROD";

Write-Host $connection

foreach ($cleanup in $CleanupNames){
    $scriptDirectory = "Cleanups/$cleanup/scripts/$CleanupTimestamp";
    
    if(!(Test-Path $scriptDirectory)){
        Write-Host "Directory '$scriptDirectory' not found"
        exit 1;
    }
    
    @(
        'WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK'

        Get-ChildItem "$scriptDirectory/*.sql" |
            Sort-Object -Property LastWriteTime -Descending |
            ForEach-Object { "@`"$($_.FullName)`"" }

        'EXIT SUCCESS'
    ) | & $sql -L $connection
}
