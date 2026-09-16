param(
    [Parameter(Mandatory = $true, HelpMessage = "Enter the cleanup name.")]
    [string]$CleanupName
)

$cleanupDirectory = "Cleanups/$CleanupName"

if (Test-Path $cleanupDirectory) {
    Write-Host "Directory '$CleanupName' already exists, skipping"
    exit 1;
}

mkdir $cleanupDirectory
mkdir "$cleanupDirectory/scripts"
New-Item "$cleanupDirectory/query.sql"

@"
using JisCleanup.Changes;
using JisCleanup.TableChanges;
using JisCleanup.Validations;

namespace JisCleanup.Cleanups;

public class Cleanup_$CleanupName : CleanupBase {
    public Cleanup_$CleanupName()
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
        
        Changes = [
            // TODO: 
            new InsertCleanupDocketEntry()
        ];
    }
}
"@ > "$cleanupDirectory/Cleanup_$CleanupName.cs"
