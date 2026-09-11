namespace JisCleanup.Changes;

public class CjisDocketDelete : DeleteTableChange
{
    public CjisDocketDelete(TableDefinition tableDefinition) : base(tableDefinition)
    {
    }
    

    public override string WherePredicate
        => """
           EXISTS
           (
               SELECT
                   1
               FROM
                   JISJDW.CHARGE charge
               INNER JOIN
                   JISJDW.CASE_DEFENDANT case_defendant
                   ON case_defendant.case_defendant_id =
                       charge.case_defendant_id
               WHERE
                   case_defendant.case_id = :case_id
                   AND charge.charge_id = source_row.charge_id
           )
           """;
}