namespace JisCleanup.Validations;

public sealed class ExternalDocketReferenceValidation : IValidation
{
    public string Validation()
        => $"""
            SELECT COUNT(*)
            INTO v_count
            FROM JISJDW.CJIS_DOCKET docket_row
            WHERE
            (
                   docket_row.first_appearance_id IN (SELECT COLUMN_VALUE FROM TABLE(v_first_appearance_id_list))
                OR docket_row.court_calendar_id IN (SELECT COLUMN_VALUE FROM TABLE(v_court_calendar_id_list))
                OR docket_row.bond_id IN (SELECT COLUMN_VALUE FROM TABLE(v_bond_id_list))
            )
            AND docket_row.cjis_docket_id NOT IN
            (
                SELECT COLUMN_VALUE FROM TABLE(v_cjis_docket_id_list)
            );

            {IValidation.Check("Hearing or bond is referenced by a docket outside the ghost docket set")}
            """;
}
