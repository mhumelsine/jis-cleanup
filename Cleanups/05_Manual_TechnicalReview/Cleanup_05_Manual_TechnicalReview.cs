using JisCleanup.Changes;
using JisCleanup.TableChanges;
using JisCleanup.Validations;

namespace JisCleanup.Cleanups;

[ManualCleanup("data.csv")]
public class Cleanup_05_Manual_TechnicalReview : CleanupBase {
    public Cleanup_05_Manual_TechnicalReview()
    {
        
        Metadata = new CleanupMetadata
        {
            Name = GetType().Name,
            Description = "TODO",
            RequestedBy = "JIS"
        };
        
        Validations =
        [
            new NoStatusOrLocationChanges()
        ];
        
        Changes = [
            new CjisDocketDelete(),
            new RestoreStatusLocation(),
            new InsertCleanupDocketEntry()
        ];
    }
}
