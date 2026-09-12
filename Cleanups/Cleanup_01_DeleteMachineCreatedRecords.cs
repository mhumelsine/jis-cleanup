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
            CaseIds = [321321,321321,321321,321321,321321]
        };

        Validations =
        [  
            new CaseDefendantCountValidation(),
            new ChargesRequiredValidation(),
            new ChargeEvidenceValidation(),
            new DocketsRequiredValidation(),
            new DocketEvidenceValidation(),
            new RootProvenanceValidation(),
            new HumanAuditValidation(),
            new AdvancedCaseGraphValidation(),
            new ExternalDocketReferenceValidation(),
            new SharedBondValidation(),
            new SharedFirstAppearanceValidation(),
            new SharedArrestCustodyValidation(),
            new SharedArrestFirstAppearanceValidation(),
            new ExternalArrestDocketValidation(),
            new ArrestProvenanceValidation(),
            new SharedInmateValidation(),
            new SatelliteProvenanceValidation(),
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