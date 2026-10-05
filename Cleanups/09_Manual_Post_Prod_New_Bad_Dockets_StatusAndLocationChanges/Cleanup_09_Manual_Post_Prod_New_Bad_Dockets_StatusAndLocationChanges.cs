using JisCleanup.Changes;
using JisCleanup.TableChanges;
using JisCleanup.Validations;

namespace JisCleanup.Cleanups;

[ManualCleanup("data.csv")]
public class Cleanup_09_Manual_Post_Prod_New_Bad_Dockets_StatusAndLocationChanges : CleanupBase {
    public Cleanup_09_Manual_Post_Prod_New_Bad_Dockets_StatusAndLocationChanges()
    {
        
        Metadata = new CleanupMetadata
        {
            Name = GetType().Name,
            Description = "Manual review cleanups of cases with bad dockets that also needed status and location changes not captured by the original bad docket view.",
            RequestedBy = "JIS"
        };
        
        Validations =
        [  
        ];
        
        Changes = [
            new RestoreStatusLocation(),
            new CjisDocketDelete(),
            new InsertCleanupDocketEntry()
        ];
    }
}
