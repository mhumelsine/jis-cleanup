namespace JisCleanup.Validations;

public sealed class ExternalArrestDocketValidation : IValidation
{
    public string Validation()
        => $"""
            SELECT COUNT(*)
            INTO v_count
            FROM JISJDW.CJIS_DOCKET docket_row
            WHERE docket_row.arrest_id IN (SELECT COLUMN_VALUE FROM TABLE(v_arrest_id_list))
              AND docket_row.cjis_docket_id NOT IN (SELECT COLUMN_VALUE FROM TABLE(v_cjis_docket_id_list));

            {IValidation.Check("ARREST is referenced by a docket outside the ghost docket set")}
            """;
}
