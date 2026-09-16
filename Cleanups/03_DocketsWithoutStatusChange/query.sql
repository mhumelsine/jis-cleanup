select distinct
    bd.cjis_spn,
    bd.cjis_case_number,
    bd.case_defendant_id,
    bd.charge_id,
    null OLD_STATUS,
    null OLD_LOCATION,
    null OLD_BOND_AMT

from JISJDW.V_PNX2JIS_BAD_DKT bd
where not exists (
    select /*+ PARALLEL */ *
    from JISJDW.CHARGE_HIST h
    where (CHANGED_COLUMNS LIKE '%LOCATION%'
        or CHANGED_COLUMNS LIKE '%STATUS%'
        or CHANGED_COLUMNS LIKE '%BOND_AMT%'
        )
      and h.CREATE_DATE_TIME > TO_DATE('2026-08-18 00:00', 'yyyy-mm-dd hh24:mi')
      AND h.CREATE_DATE_TIME <= TO_DATE('2026-09-01 00:00', 'yyyy-mm-dd hh24:mi')
      and bd.CHARGE_ID = h.CHARGE_ID
)