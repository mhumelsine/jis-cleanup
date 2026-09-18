param(
    [Parameter(Mandatory = $true, HelpMessage = "Enter the cleanup timestamp.")]
    [string[]]$CleanupTimestamp,
        
    [Parameter(Mandatory = $true, HelpMessage = "Enter the cleanup name.")]
    [string[]]$CleanupNames
)

#set local env vars
Get-Content .env | ForEach-Object {
    $k, $v = $_ -split '=', 2
    [System.Environment]::SetEnvironmentVariable($k.Trim(), $v.Trim())

}

dotnet run -- "run" $CleanupTimestamp $CleanupNames