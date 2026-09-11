namespace JisCleanup.Validations;

public sealed class DocketsRequiredValidation : IValidation
{
    public string Validation()
        => """
            SELECT COUNT(*)
            INTO v_count
            FROM TABLE(v_cjis_docket_id_list);

            v_is_valid := 1;
            v_validation_error := NULL;

            IF v_count = 0 THEN
                v_is_valid := 0;
                v_validation_error := 'Case has no dockets';
            END IF;
            """;
}
