using JisCleanup.Changes;
using JisCleanup.TableChanges;

namespace JisCleanup.Cleanups;

[ManualCleanup("data.csv")]
public class Cleanup_10_Manual_Rearrest_NoBadDockets : CleanupBase {
    public Cleanup_10_Manual_Rearrest_NoBadDockets()
    {
        
        Metadata = new CleanupMetadata
        {
            Name = GetType().Name,
            Description = "Rearrests that had no corresponding bad docket entries to remove.",
            RequestedBy = "JIS"
        };
        
        Validations =
        [  
        ];
        
        Changes = [
            new RestoreStatusLocation()
        ];
    }
}
