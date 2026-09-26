using JisCleanup.Changes;
using JisCleanup.TableChanges;
using JisCleanup.Validations;

namespace JisCleanup.Cleanups;

[ManualCleanup("data.csv")]
public class Cleanup_04_Manual_TechnicalReview : CleanupBase {
    public Cleanup_04_Manual_TechnicalReview()
    {
        
        Metadata = new CleanupMetadata
        {
            Name = GetType().Name,
            Description = "Deep technical review of cases with human activity since 8/18.",
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
