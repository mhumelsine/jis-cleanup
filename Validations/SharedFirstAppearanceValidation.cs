namespace JisCleanup.Validations;

public sealed class SharedFirstAppearanceValidation : IValidation
{
    public string Validation()
        => $"""
            SELECT COUNT(*)
            INTO v_count
            FROM JISJDW.FA_CHARGE fa_charge_row
            WHERE fa_charge_row.first_appearance_id IN
                  (SELECT COLUMN_VALUE FROM TABLE(v_first_appearance_id_list))
              AND fa_charge_row.charge_id NOT IN
                  (SELECT COLUMN_VALUE FROM TABLE(v_charge_id_list));

            {IValidation.Check("FIRST_APPEARANCE is shared with a charge outside the ghost case")}
            """;
}
