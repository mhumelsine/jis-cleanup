namespace JisCleanup.Validations;

public sealed class SharedInmateValidation : IValidation
{
    public string Validation()
        => $"""
            SELECT COUNT(*)
            INTO v_count
            FROM JISJDW.ARREST arrest_row
            WHERE arrest_row.inmate_id IN (SELECT COLUMN_VALUE FROM TABLE(v_inmate_id_list))
              AND arrest_row.arrest_id NOT IN (SELECT COLUMN_VALUE FROM TABLE(v_arrest_id_list));

            {IValidation.Check("INMATE is shared by an arrest outside the ghost graph")}
            """;
}
