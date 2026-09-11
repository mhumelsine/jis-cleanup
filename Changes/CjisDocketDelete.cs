namespace JisCleanup.TableChanges;

public sealed class CjisDocketDelete : DeleteTableChange
{
    public CjisDocketDelete()
        : base(new TableDefinition(
            "JISJDW",
            "CJIS_DOCKET",
            "CJIS_DOCKET_ID"))
    {
    }

    public override string WherePredicate
        => """
            source_row.charge_id IN
            (
                SELECT charge_row.charge_id
                FROM JISJDW.CHARGE charge_row
                WHERE charge_row.case_defendant_id IN
                (
                    SELECT case_defendant_row.case_defendant_id
                    FROM JISJDW.CASE_DEFENDANT case_defendant_row
                    WHERE case_defendant_row.case_id = v_case_id
                )
            )
            """;

    public override string Apply()
        => $"""
            -- Capture context that cannot be derived after dependent rows are deleted.
            SELECT DISTINCT target_row.arrest_id
            BULK COLLECT INTO v_arrest_id_list
            FROM
            (
                SELECT custody_row.arrest_id
                FROM JISJDW.CUSTODY_STATUS custody_row
                WHERE custody_row.charge_id IN
                (
                    SELECT charge_row.charge_id
                    FROM JISJDW.CHARGE charge_row
                    WHERE charge_row.case_defendant_id IN
                    (
                        SELECT case_defendant_row.case_defendant_id
                        FROM JISJDW.CASE_DEFENDANT case_defendant_row
                        WHERE case_defendant_row.case_id = v_case_id
                    )
                )
            
                UNION
            
                SELECT docket_row.arrest_id
                FROM JISJDW.CJIS_DOCKET docket_row
                WHERE docket_row.charge_id IN
                (
                    SELECT charge_row.charge_id
                    FROM JISJDW.CHARGE charge_row
                    WHERE charge_row.case_defendant_id IN
                    (
                        SELECT case_defendant_row.case_defendant_id
                        FROM JISJDW.CASE_DEFENDANT case_defendant_row
                        WHERE case_defendant_row.case_id = v_case_id
                    )
                )
            
                UNION
            
                SELECT appearance_row.arrest_id
                FROM JISJDW.FIRST_APPEARANCE appearance_row
                WHERE appearance_row.case_defendant_id IN
                (
                    SELECT case_defendant_row.case_defendant_id
                    FROM JISJDW.CASE_DEFENDANT case_defendant_row
                    WHERE case_defendant_row.case_id = v_case_id
                )
            ) target_row
            WHERE target_row.arrest_id IS NOT NULL;
            
            SELECT DISTINCT arrest_row.inmate_id
            BULK COLLECT INTO v_inmate_id_list
            FROM JISJDW.ARREST arrest_row
            WHERE arrest_row.arrest_id IN
            (
                SELECT COLUMN_VALUE
                FROM TABLE(v_arrest_id_list)
            )
            AND arrest_row.inmate_id IS NOT NULL;
            
            DELETE
            FROM {TargetTableName} source_row
            WHERE {WherePredicate}
            RETURNING
                source_row.{TableDefinition.PrimaryKeyColumn}
            BULK COLLECT INTO
                {AffectedIdListName};
            """;
}
