using JisCleanup.Changes;
using JisCleanup.TableChanges;
using JisCleanup.Validations;

namespace JisCleanup.Cleanups;

public class Cleanup_04_Current_Inmates_With_Status_Changes : CleanupBase {
    public Cleanup_04_Current_Inmates_With_Status_Changes()
    {
        
        Metadata = new CleanupMetadata
        {
            Name = GetType().Name,
            Description = "Target current Inmates with changes to status, location, or bond amount",
            RequestedBy = "JIS"
        };
        
        Validations =
        [  
        ];
        
        Changes = [
            new RestoreStatusLocationBondAmount(),
            new CjisDocketDelete(),
            new InsertCleanupDocketEntry()
        ];
    }
}
