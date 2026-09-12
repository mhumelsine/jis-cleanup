namespace JisCleanup.Validations;

public sealed class SharedArrestCustodyValidation : IValidation
{
    public string Validation()
        => """
            SELECT 
              COUNT(*) INTO v_count 
            FROM 
              JISJDW.CUSTODY_STATUS cs 
            WHERE 
              (
                EXISTS (
                  SELECT 
                    1 
                  FROM 
                    JISJDW.CUSTODY_STATUS cs_1 
                  WHERE 
                    cs.arrest_id = cs_1.arrest_id 
                    AND EXISTS (
                      SELECT 
                        1 
                      FROM 
                        JISJDW.CHARGE ch 
                        JOIN JISJDW.CASE_DEFENDANT cd ON cd.case_defendant_id = ch.case_defendant_id 
                      WHERE 
                        ch.charge_id = cs.charge_id 
                        AND cd.case_id = v_case_id
                    )
                ) 
                OR EXISTS (
                  SELECT 
                    1 
                  FROM 
                    JISJDW.CJIS_DOCKET d 
                  WHERE 
                    d.arrest_id = cs.arrest_id 
                    AND EXISTS (
                      SELECT 
                        1 
                      FROM 
                        JISJDW.CHARGE ch 
                        JOIN JISJDW.CASE_DEFENDANT cd ON cd.case_defendant_id = ch.case_defendant_id 
                      WHERE 
                        ch.charge_id = d.charge_id 
                        AND cd.case_id = v_case_id
                    )
                ) 
                OR EXISTS (
                  SELECT 
                    1 
                  FROM 
                    JISJDW.FIRST_APPEARANCE fa 
                  WHERE 
                    fa.arrest_id = cs.arrest_id 
                    AND EXISTS (
                      SELECT 
                        1 
                      FROM 
                        JISJDW.CASE_DEFENDANT cd 
                      WHERE 
                        cd.case_defendant_id = fa.case_defendant_id 
                        AND cd.case_id = v_case_id
                    )
                )
              ) 
              AND NOT EXISTS (
                SELECT 
                  1 
                FROM 
                  JISJDW.CHARGE ch 
                WHERE 
                  ch.charge_id = cs.charge_id 
                  AND EXISTS (
                    SELECT 
                      1 
                    FROM 
                      JISJDW.CASE_DEFENDANT cd 
                    WHERE 
                      cd.case_defendant_id = ch.case_defendant_id 
                      AND cd.case_id = v_case_id
                  )
              );

            v_is_valid := 1;
            v_validation_error := NULL;
                               
            IF v_count > 0 THEN 
               v_is_valid := 0;
                v_validation_error := 'ARREST is shared by custody on another charge';
            END IF;
            
            """;
}
