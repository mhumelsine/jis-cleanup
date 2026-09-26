using JisCleanup.Changes;
using JisCleanup.TableChanges;
using JisCleanup.Validations;

namespace JisCleanup.Cleanups;

public class Cleanup_05_Current_Inmates_StatusChanges_With_NoHumanAction : CleanupBase {
    public Cleanup_05_Current_Inmates_StatusChanges_With_NoHumanAction()
    {
        
        Metadata = new CleanupMetadata
        {
            Name = GetType().Name,
            Description = "Target current Inmates with changes to status, location, or bond amount that have no human activity in the audit trail after the first status, location, or bond amt change in the go live period.",
            RequestedBy = "JIS"
        };
        
        Validations =
        [  
            new NoHumanChargeActivity()
        ];
        
        Changes = [
            new RestoreStatusLocationBondAmount(),
            new CjisDocketDelete(),
            new InsertCleanupDocketEntry()
        ];
    }
}
