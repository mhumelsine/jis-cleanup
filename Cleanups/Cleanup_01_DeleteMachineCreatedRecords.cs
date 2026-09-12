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
            CaseIds = [
                new CaseId("2026CF1202A"),
                new CaseId("2026CF839A"),
                new CaseId("2026CF839A")
            ]
        };
        
        Validations =
        [  
            new MustBeSingleDefendant(),
            new MustHaveAtLeastOneCharge(),
            //have charge in scope
            //have docket in scope
            //has a docket outside the scope
            //must only have machine activity
            new MustNotHaveProgressedPastBooking(),
            new NoBondOutsideGhostDocket(),
            new NoFirstAppearanceOutsideGhostDocket(),
            new NoHearingOutsideGhostDocket(),
            new NoSharedReleaseBond()
        ];
        
        Changes = [
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
            new JailActivityDelete(),
            new InmateDelete(),
            new CaseDefendantDelete(),
            new CjisCaseDelete()
        ];
    }
}