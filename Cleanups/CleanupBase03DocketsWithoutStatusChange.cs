using JisCleanup.TableChanges;

namespace JisCleanup.Cleanups;

public class CleanupBase03DocketsWithoutStatusChange : CleanupBase
{
    public CleanupBase03DocketsWithoutStatusChange()
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