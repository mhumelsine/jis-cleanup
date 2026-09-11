namespace JisCleanup.TableChanges;

public sealed class CjisDocketDelete : DeleteTableChange
{
    public CjisDocketDelete()
        : base(new TableDefinition("JISJDW", "CJIS_DOCKET", "CJIS_DOCKET_ID"))
    {
    }

    public override string LoadContext()
        => """
            SELECT docket_row.cjis_docket_id
            BULK COLLECT INTO v_cjis_docket_id_list
            FROM JISJDW.CJIS_DOCKET docket_row
            WHERE docket_row.charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_id_list))
            FOR UPDATE NOWAIT;
            """;

    public override string WherePredicate
        => """
            source_row.cjis_docket_id IN (SELECT COLUMN_VALUE FROM TABLE(v_cjis_docket_id_list))
            """;
}
