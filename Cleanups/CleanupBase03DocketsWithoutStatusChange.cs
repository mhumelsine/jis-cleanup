using JisCleanup.TableChanges;

namespace JisCleanup.Cleanups;

public class Cleanup_03_DocketsWithoutStatusChange : CleanupBase
{
    public Cleanup_03_DocketsWithoutStatusChange()
    {
        Metadata = new CleanupMetadata
        {
            Name = GetType().Name,
            Description = "Removes docket entries that do not status, location, or bond changes between 08/18 and 09/01",
            RequestedBy = "JIS"
        };

        Changes =
        [
            new CjisDocketDelete(),
            new InsertCleanupDocketEntry()
        ];
    }
}