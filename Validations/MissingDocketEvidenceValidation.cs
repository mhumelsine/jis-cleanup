namespace JisCleanup.Validations;

public sealed class MissingDocketEvidenceValidation : IValidation
{
    public string Validation()
        => $"""
            SELECT COUNT(*)
            INTO v_count
            FROM JISJDW.CJIS_DOCKET docket_row
            WHERE docket_row.charge_id IN
            (
                SELECT COLUMN_VALUE FROM TABLE(v_charge_id_list)
            )
            AND NOT EXISTS
            (
                SELECT 1
                FROM JISJDW.V_PNX2JIS_BAD_DKT evidence_row
                WHERE evidence_row.cjis_docket_id = docket_row.cjis_docket_id
            );

            {IValidation.Check("Case contains a docket not present in V_PNX2JIS_BAD_DKT")}
            """;
}
