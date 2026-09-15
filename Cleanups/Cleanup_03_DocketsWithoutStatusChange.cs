using JisCleanup.TableChanges;

namespace JisCleanup.Cleanups;

public class Cleanup_03_DocketsWithoutStatusChange : Cleanup
{
    public Cleanup_03_DocketsWithoutStatusChange()
    {
        Metadata = new CleanupMetadata
        {
            Name = GetType().Name,
            Description = "Removes docket entries that do not status changes",
            RequestedBy = "JIS",
            RunNumber = 1
        };

        Changes =
        [
            new CjisDocketDelete(),
            new InsertCleanupDocketEntry()
        ];
    }
}