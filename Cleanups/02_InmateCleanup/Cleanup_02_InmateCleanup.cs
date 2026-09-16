using JisCleanup.Changes;
using JisCleanup.TableChanges;
using JisCleanup.Validations;

namespace JisCleanup.Cleanups;

public class Cleanup_02_InmateCleanup : CleanupBase
{
    public Cleanup_02_InmateCleanup()
    {
        
        Metadata = new CleanupMetadata
        {
            Name = GetType().Name,
            Description = "All Inmates that have status, location, or bond amount changes",
            RequestedBy = "JIS",
            RunNumber = 2
        };
        
        Validations =
        [  
            new NoHumanActivity()
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