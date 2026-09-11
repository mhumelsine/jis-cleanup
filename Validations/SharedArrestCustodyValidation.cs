namespace JisCleanup.Validations;

public sealed class SharedArrestCustodyValidation : IValidation
{
    public string Validation()
        => $"""
            SELECT COUNT(*)
            INTO v_count
            FROM JISJDW.CUSTODY_STATUS custody_row
            WHERE custody_row.arrest_id IN (SELECT COLUMN_VALUE FROM TABLE(v_arrest_id_list))
              AND custody_row.charge_id NOT IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_id_list));

            {IValidation.Check("ARREST is shared by custody on another charge")}
            """;
}
