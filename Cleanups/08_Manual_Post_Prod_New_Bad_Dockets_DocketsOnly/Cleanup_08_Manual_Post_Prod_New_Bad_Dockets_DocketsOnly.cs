using JisCleanup.Changes;
using JisCleanup.TableChanges;
using JisCleanup.Validations;

namespace JisCleanup.Cleanups;

[ManualCleanup("data.csv")]
public class Cleanup_08_Manual_Post_Prod_New_Bad_Dockets_DocketsOnly : CleanupBase {
    public Cleanup_08_Manual_Post_Prod_New_Bad_Dockets_DocketsOnly()
    {
        
        Metadata = new CleanupMetadata
        {
            Name = GetType().Name,
            Description = "Manual review cleanups of cases with only bad dockets not captured by the original bad docket view.",
            RequestedBy = "JIS"
        };
        
        Validations =
        [  
        ];
        
        Changes = [
            new CjisDocketDelete(),
            new InsertCleanupDocketEntryNoStatusChange()
        ];
    }
}
