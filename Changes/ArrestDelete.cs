namespace JisCleanup;

public sealed class ArrestDelete : DeleteTableChange
{
    public ArrestDelete()
        : base(new TableDefinition("JISJDW", "ARREST", "ARREST_ID"))
    {
    }

    public override string WherePredicate
        => """
            EXISTS
            (
                SELECT 1
                FROM JISREM.CUSTODY_STATUS zcs
                JOIN JISREM.CHARGE zch
                  ON zch.cleanup_id = zcs.cleanup_id
                 AND zch.row_state = 'BEFORE'
                 AND zch.charge_id = zcs.charge_id
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = zch.case_defendant_id
                WHERE zcs.cleanup_id = :cleanup_id
                  AND zcs.row_state = 'BEFORE'
                  AND zcs.arrest_id = source_row.arrest_id
                  AND cd.case_id = v_case_id
            )
            OR EXISTS
            (
                SELECT 1
                FROM JISREM.CJIS_DOCKET zd
                JOIN JISREM.CHARGE zch
                  ON zch.cleanup_id = zd.cleanup_id
                 AND zch.row_state = 'BEFORE'
                 AND zch.charge_id = zd.charge_id
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = zch.case_defendant_id
                WHERE zd.cleanup_id = :cleanup_id
                  AND zd.row_state = 'BEFORE'
                  AND zd.arrest_id = source_row.arrest_id
                  AND cd.case_id = v_case_id
            )
            OR EXISTS
            (
                SELECT 1
                FROM JISREM.FIRST_APPEARANCE zfa
                JOIN JISJDW.CASE_DEFENDANT cd
                  ON cd.case_defendant_id = zfa.case_defendant_id
                WHERE zfa.cleanup_id = :cleanup_id
                  AND zfa.row_state = 'BEFORE'
                  AND zfa.arrest_id = source_row.arrest_id
                  AND cd.case_id = v_case_id
            )
            """;
}
