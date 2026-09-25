using JisCleanup.Changes;
using JisCleanup.TableChanges;
using JisCleanup.Validations;

namespace JisCleanup.Cleanups;

public class Cleanup_04b_Current_Inmates_With_Status_Changes_DocketsOnly : CleanupBase {
    public Cleanup_04b_Current_Inmates_With_Status_Changes_DocketsOnly()
    {
        
        Metadata = new CleanupMetadata
        {
            Name = GetType().Name,
            Description = "Target current Inmates with changes to status, location, or bond amount.  Only remove bad dockets",
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
