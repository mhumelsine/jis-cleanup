using JisCleanup.Changes;
using JisCleanup.TableChanges;

namespace JisCleanup.Cleanups;

[ManualCleanup("data.csv")]
public class Cleanup_00_OOSC_WithRemaining_BadDockets : CleanupBase {
    public Cleanup_00_OOSC_WithRemaining_BadDockets()
    {
        
        Metadata = new CleanupMetadata
        {
            Name = GetType().Name,
            Description = "Cases that had an OOSC after bad docket entries, but bad docket entries were not removed.",
            RequestedBy = "JIS"
        };
        
        Validations =
        [  
        ];
        
        Changes = [
            new CjisDocketByCaseDelete(),
            new InsertCleanupDocketEntryNoStatusChange()
        ];
    }
}
