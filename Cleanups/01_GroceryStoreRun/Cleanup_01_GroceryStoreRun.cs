using JisCleanup.Changes;
using JisCleanup.TableChanges;
using JisCleanup.Validations;

namespace JisCleanup.Cleanups;

public class Cleanup_01_GroceryStoreRun : CleanupBase {
    public Cleanup_01_GroceryStoreRun()
    {
        
        Metadata = new CleanupMetadata
        {
            Name = GetType().Name,
            Description = "Grocery store run; Initial cleanup of around 395 cases with only invalid system activity",
            RequestedBy = "JIS",
        };
        
        Validations =
        [  
            new NoHumanChargeActivity()
        ];
        
        Changes = [
            new RestoreStatusLocationBondAmount(),
            new CjisDocketDelete(),
            new FaChargeDelete(),
            new CourtCalendarDelete(),
            new FirstAppearanceDelete(), 
            new CustodyStatusDelete(), 
            new ReleaseBondDelete(),
            new InsertCleanupDocketEntry()
        ];
    }
}