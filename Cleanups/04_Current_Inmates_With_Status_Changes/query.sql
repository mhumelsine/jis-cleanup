with last_change_hist as (
    select *
    from (
             select
                 row_number() over (partition by h.CHARGE_NUMBER order by h.CHARGE_HIST_ID) rank_order
        
            , h.CHARGE_ID
                  , h.OLD_BOND_AMT
                  , h.OLD_LOCATION
                  , h.OLD_STATUS
                  , h.NEW_BOND_AMT
                  , h.NEW_LOCATION
                  , h.NEW_STATUS
                  , h.CHANGED_COLUMNS
             from JISJDW.CHARGE_HIST h
             where (
                 CHANGED_COLUMNS LIKE '%LOCATION%'
                     or CHANGED_COLUMNS LIKE '%STATUS%'
                     or CHANGED_COLUMNS LIKE '%BOND_AMT%'
                 )
               and CREATE_DATE_TIME >= TO_DATE('2026-08-18 00:00', 'yyyy-mm-dd hh24:mi')
               and CREATE_DATE_TIME <= TO_DATE('2026-09-01 00:00', 'yyyy-mm-dd hh24:mi')
         )
    where rank_order = 1
)

select distinct
    bd.cjis_spn,
    bd.cjis_case_number,
    bd.case_defendant_id,
    bd.charge_id,
    h.OLD_STATUS,
    h.OLD_LOCATION,
    h.OLD_BOND_AMT

from JISJDW.V_PNX2JIS_BAD_DKT bd

inner join last_change_hist h
on bd.CHARGE_ID = h.CHARGE_ID

where exists (
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
  and exists (
    select *
    from JISJDW.INMATE i
    --EVERYONE currently in jail or in jail on 8/18
    where i.PHYSICAL_RELEASE_DATE IS NULL
      AND i.CJIS_SPN = bd.CJIS_SPN
)