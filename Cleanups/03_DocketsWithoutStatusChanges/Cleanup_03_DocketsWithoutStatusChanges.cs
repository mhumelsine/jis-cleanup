using JisCleanup.Changes;
using JisCleanup.TableChanges;
using JisCleanup.Validations;

namespace JisCleanup.Cleanups;

public class Cleanup_03_DocketsWithoutStatusChanges : CleanupBase {
    public Cleanup_03_DocketsWithoutStatusChanges()
    {
        
        Metadata = new CleanupMetadata
        {
            Name = GetType().Name,
            Description = "Removes docket entries that do not status changes",
            RequestedBy = "JIS"
        };
        
        Validations =
        [  
        ];
        
        Changes = [
            new CjisDocketDelete(),
            new InsertCleanupDocketEntry()
        ];
    }
}
