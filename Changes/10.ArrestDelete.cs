namespace JisCleanup.TableChanges;

public sealed class ArrestDelete : DeleteTableChange
{
    public ArrestDelete()
        : base(new TableDefinition("JISJDW", "ARREST", "ARREST_ID"))
    {
    }

    public override string LoadContext()
        => """
            SELECT DISTINCT arrest_id
            BULK COLLECT INTO v_arrest_id_list
            FROM
            (
                SELECT arrest_id FROM JISJDW.CUSTODY_STATUS
                WHERE charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_id_list))
                UNION
                SELECT arrest_id FROM JISJDW.CJIS_DOCKET
                WHERE cjis_docket_id IN (SELECT COLUMN_VALUE FROM TABLE(v_cjis_docket_id_list))
                UNION
                SELECT arrest_id FROM JISJDW.FIRST_APPEARANCE
                WHERE first_appearance_id IN (SELECT COLUMN_VALUE FROM TABLE(v_first_appearance_id_list))
            )
            WHERE arrest_id IS NOT NULL;
            """;

    public override string WherePredicate
        => """
            source_row.arrest_id IN (SELECT COLUMN_VALUE FROM TABLE(v_arrest_id_list))
            """;
}
