namespace JisCleanup.Changes;

public class ArrestDelete : DeleteTableChange
{
    public ArrestDelete() : 
        base(new TableDefinition("JISJDW", "ARREST", "ARREST_ID"))
    {
    }
    
    public override string WherePredicate
        => """
           EXISTS
           (
               SELECT
                   1
               FROM
                   JISJDW.CUSTODY_STATUS custody
               INNER JOIN
                   JISJDW.CHARGE charge
                   ON charge.charge_id = custody.charge_id
               INNER JOIN
                   JISJDW.CASE_DEFENDANT case_defendant
                   ON case_defendant.case_defendant_id =
                       charge.case_defendant_id
               WHERE
                   case_defendant.case_id = :case_id
                   AND custody.arrest_id = source_row.arrest_id
           )
           OR EXISTS
           (
               SELECT
                   1
               FROM
                   JISJDW.CJIS_DOCKET docket
               INNER JOIN
                   JISJDW.CHARGE charge
                   ON charge.charge_id = docket.charge_id
               INNER JOIN
                   JISJDW.CASE_DEFENDANT case_defendant
                   ON case_defendant.case_defendant_id =
                       charge.case_defendant_id
               WHERE
                   case_defendant.case_id = :case_id
                   AND docket.arrest_id = source_row.arrest_id
           )
           OR EXISTS
           (
               SELECT
                   1
               FROM
                   JISJDW.FIRST_APPEARANCE appearance
               INNER JOIN
                   JISJDW.CASE_DEFENDANT case_defendant
                   ON case_defendant.case_defendant_id =
                       appearance.case_defendant_id
               WHERE
                   case_defendant.case_id = :case_id
                   AND appearance.arrest_id = source_row.arrest_id
           )
           """;
}