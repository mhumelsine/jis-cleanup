namespace JisCleanup.Validations;

public sealed class SharedArrestFirstAppearanceValidation : IValidation
{
    public string Validation()
        => $"""
            SELECT COUNT(*)
            INTO v_count
            FROM JISJDW.FIRST_APPEARANCE fa_row
            WHERE fa_row.arrest_id IN (SELECT COLUMN_VALUE FROM TABLE(v_arrest_id_list))
              AND fa_row.case_defendant_id <> v_case_defendant_id;

            {IValidation.Check("ARREST is shared by another case FIRST_APPEARANCE")}
            """;
}
