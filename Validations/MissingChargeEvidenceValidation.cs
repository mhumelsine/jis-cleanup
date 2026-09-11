namespace JisCleanup.Validations;

public sealed class MissingChargeEvidenceValidation : IValidation
{
    public string Validation()
        => $"""
            SELECT COUNT(*)
            INTO v_count
            FROM TABLE(v_charge_id_list) charge_row
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM JISJDW.V_PNX2JIS_BAD_DKT evidence_row
                WHERE evidence_row.charge_id = charge_row.COLUMN_VALUE
            );

            {IValidation.Check("One or more charges have no V_PNX2JIS_BAD_DKT evidence")}
            """;
}
