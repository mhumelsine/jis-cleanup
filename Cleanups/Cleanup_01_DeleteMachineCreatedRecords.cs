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
            new ChargeMustHaveBadDocketEvidence(),
            new CaseMustHaveAtLeastOneDocket(),
            new NoDocketsOutsideBadDocketScope(),
            new CjisCaseMustNotHaveHumanChanges(),
            new CaseDefendantMustNotHaveHumanChanges(),
            new ChargeMustNotHaveHumanChanges(),
            new CjisDocketMustNotHaveHumanChanges(),
            new MustNotHaveProgressedPastBooking(),
            new NoBondOutsideGhostDocket(),
            new NoFirstAppearanceOutsideGhostDocket(),
            new NoHearingOutsideGhostDocket(),
            new NoSharedReleaseBond(),
            new NoSharedFirstAppearance(),
            new NoSharedArrestCustody(),
            new NoSharedArrestFirstAppearance(),
            new NoArrestOutsideGhostDocket(),
            new ArrestMustNotHaveHumanChanges(),
            new NoSharedInmateArrest(),
            new CustodyMustNotHaveHumanChanges(),
            new BondMustNotHaveHumanChanges(),
            new FirstAppearanceMustNotHaveHumanChanges(),
            new FaChargeMustNotHaveHumanChanges(),
            new CourtCalendarMustNotHaveHumanChanges(),
            new ChargeJailInfoMustNotHaveHumanChanges(),
            //new ArrestMustNotHaveHumanChanges() //TODO:  This was in the code twice
            new InmateMustNotHaveHumanChanges(),
            new JailActivityMustNotHaveHumanChanges(),
            new CaseRelatedPersonNotHaveHumanChanges()
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