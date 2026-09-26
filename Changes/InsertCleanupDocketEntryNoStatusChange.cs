namespace JisCleanup.TableChanges;

public class InsertCleanupDocketEntryNoStatusChange : InsertTableChange
{
    public InsertCleanupDocketEntryNoStatusChange() 
        : base(new TableDefinition("JISJDW", "CJIS_DOCKET", "CJIS_DOCKET_ID"), "JISJDW.cjis_docket_seq")
    {
    }

    protected override string Apply(Charge charge)
        => $"""
           SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
                WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
           INTO v_docket_id_str
           FROM JISREM.CJIS_DOCKET
           WHERE row_state = 'BEFORE'
           AND change_action = 'DELETE'
           AND CHARGE_ID = {charge.ChargeId}
           AND cleanup_id = __CLEANUP_ID__;

           --ensure at least 1 docket was deleted
           IF v_docket_id_str IS NOT NULL THEN
                    
               INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
               VALUES (v_inserted_id, '{charge.ChargeId}', SYSDATE,SYSDATE, 'APPF',
                      'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
                      'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
                      'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
                      ' NO OTHER DOCKET ENTRY ALTERED.'||
                      ' JIS RECORD CORRECTION, BATCH ' || __CLEANUP_ID__ );
              
                v_count := SQL%ROWCOUNT;
           END IF;

           """;
}