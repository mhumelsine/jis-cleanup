namespace JisCleanup.TableChanges;

public class InsertCleanupDocketEntry : InsertTableChange
{
    public InsertCleanupDocketEntry() 
        : base(new TableDefinition("JISJDW", "CJIS_DOCKET", "CJIS_DOCKET_ID"), "JISJDW.cjis_docket_seq")
    {
    }

    protected override string Apply(Charge charge)
        => $"""
           SELECT LISTAGG(TO_CHAR(cjis_docket_id), ', ')
                WITHIN GROUP (ORDER BY cjis_docket_id) AS charge_list
           INTO v_docket_id_str
           FROM JISREM.CJIS_DOCKET
           WHERE row_state = 'BEFORE'
           AND change_action = 'DELETE';
                    
           INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
           VALUES (v_inserted_id, '{charge.ChargeId}', SYSDATE,SYSDATE, 'APPF',
                  'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
                  'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
                  'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
                  ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
                  ' JIS RECORD CORRECTION, BATCH ' || :CLEANUP_ID );

           """;
}