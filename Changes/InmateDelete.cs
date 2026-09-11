namespace JisCleanup.TableChanges;

public sealed class InmateDelete : DeleteTableChange
{
    public InmateDelete()
        : base(new TableDefinition("JISJDW", "INMATE", "INMATE_ID"))
    {
    }

    public override string LoadContext()
        => """
            SELECT DISTINCT arrest_row.inmate_id
            BULK COLLECT INTO v_inmate_id_list
            FROM JISJDW.ARREST arrest_row
            WHERE arrest_row.arrest_id IN (SELECT COLUMN_VALUE FROM TABLE(v_arrest_id_list))
              AND arrest_row.inmate_id IS NOT NULL;
            """;

    public override string WherePredicate
        => """
            source_row.inmate_id IN (SELECT COLUMN_VALUE FROM TABLE(v_inmate_id_list))
            """;
}
