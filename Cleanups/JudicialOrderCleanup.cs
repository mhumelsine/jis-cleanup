using JisCleanup.Changes;

namespace JisCleanup.Cleanups;

public class JudicialOrderCleanupBase : CleanupBase
{
    public JudicialOrderCleanupBase()
    {
        Metadata = new CleanupMetadata
        {
            Name = "Judicial_Order_2024CF1550",
            Description = "Manual correction for single case",
            RequestedBy = "Jessica Gillespie",
        };

        Validations = [];

        Changes =
        [
            new RestoreStatusLocationBondAmount(),
            new CjisDocketDelete()
        ];
    }
}