using JisCleanup.TableChanges;

namespace JisCleanup.Cleanups;

[ManualCleanup("data.csv")]
public class Cleanup_00_OOSC_WithRemaining_BadDockets : CleanupBase {
    public Cleanup_00_OOSC_WithRemaining_BadDockets()
    {
        
        Metadata = new CleanupMetadata
        {
            Name = GetType().Name,
            Description = "Case that had a OOSC after the bad docket entries, but the bad docket entries were not removed.",
            RequestedBy = "JIS"
        };
        
        Validations =
        [  
        ];
        
        Changes = [
            new CjisDocketDelete(),
            new InsertCleanupDocketEntry()
        ];
    }
}
