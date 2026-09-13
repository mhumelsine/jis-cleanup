using JisCleanup.Changes;
using JisCleanup.TableChanges;
using JisCleanup.Validations;

namespace JisCleanup.Cleanups;

public class Cleanup_01_DeleteMachineCreatedRecords : Cleanup {
    public Cleanup_01_DeleteMachineCreatedRecords()
    {
        
        Metadata = new CleanupMetadata
        {
            Name = GetType().Name,
            Description = "TODODODOD",
            RequestedBy = "Michael Humelsine",
        };
        
        Validations =
        [  
            new NoHumanActivity()
        ];
        
        Changes = [
            new RestoreStatusLocationBondAmount(),
            new CjisDocketDelete(),
            new FaChargeDelete(),
            new CourtCalendarDelete(),
            new FirstAppearanceDelete(), 
            new CustodyStatusDelete(), 
            new ReleaseBondDelete(),
            new ChargeJailInfoDelete(),
            new CaseRelatedPersonDelete(),
            new ChargeDelete(),
            new ArrestDelete(),
            // new JailActivityDelete(),
            // new InmateDelete(),
            // new CaseDefendantDelete(),
            // new CjisCaseDelete(),
            new InsertCleanupDocketEntry()
        ];
    }
}