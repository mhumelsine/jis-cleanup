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
            Description = "Initial cleanup of around 395 cases with only invalid system activity",
            RequestedBy = "JIS",
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
            // new ChargeJailInfoDelete(),  //TODO:  Should we delete or not
            // new CaseRelatedPersonDelete(),  //TODO:  
            // new ChargeDelete(), //TODO:  Should we delete or not?
            // new ArrestDelete(),
            // new JailActivityDelete(),
            // new InmateDelete(),
            // new CaseDefendantDelete(),
            // new CjisCaseDelete(),
            new InsertCleanupDocketEntry()
        ];
    }
}