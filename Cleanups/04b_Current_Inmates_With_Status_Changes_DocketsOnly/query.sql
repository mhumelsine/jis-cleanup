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
                  , h.CREATE_USER_ID
                  ,h.CHARGE_HIST_ID
                  ,h.CREATE_DATE_TIME
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
),
     charge_history_change_deltas as (
         select
             CHARGE_HIST_ID
              ,lag(CREATE_DATE_TIME, 1) over(partition by CHARGE_NUMBER order by CHARGE_HIST_ID) previous_create_date_time
            ,FIRST_VALUE(CHARGE_HIST_ID) over(partition by CHARGE_NUMBER order by CHARGE_HIST_ID desc) last_charge_history_id
            ,FIRST_VALUE(CREATE_DATE_TIME) over(partition by CREATE_DATE_TIME order by CHARGE_HIST_ID desc) last_charge_date_time
            ,CREATE_DATE_TIME
         from JISJDW.CHARGE_HIST
     )

select distinct
    bd.cjis_spn,
    bd.cjis_case_number,
    bd.case_defendant_id,
    bd.charge_id,
    null OLD_STATUS,
    null OLD_LOCATION,
    null OLD_BOND_AMT
from JISJDW.V_PNX2JIS_BAD_DKT bd

         inner join last_change_hist h
                    on bd.CHARGE_ID = h.CHARGE_ID

         inner join charge_history_change_deltas cd
                    on h.CHARGE_HIST_ID = cd.CHARGE_HIST_ID

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