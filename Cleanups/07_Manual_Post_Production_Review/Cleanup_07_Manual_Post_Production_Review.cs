using JisCleanup.Changes;
using JisCleanup.TableChanges;

namespace JisCleanup.Cleanups;

[ManualCleanup("data.csv")]
public class Cleanup_07_Manual_Post_Production_Review : CleanupBase {
    public Cleanup_07_Manual_Post_Production_Review()
    {
        
        Metadata = new CleanupMetadata
        {
            Name = GetType().Name,
            Description = "Manual cleanups/corrections after production review.",
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
