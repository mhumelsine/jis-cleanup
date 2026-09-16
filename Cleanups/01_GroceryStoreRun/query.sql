with target_set as (
    select
        b.cjis_spn,
        b.cjis_case_number,
        b.case_defendant_id,
        b.charge_id,
        last_charge_hist.OLD_STATUS,
        last_charge_hist.OLD_LOCATION,
        last_charge_hist.OLD_BOND_AMT
    from jisjdw.charge c, -- all charges in the database
         (
             select x.case_defendant_id,x.cjis_spn,x.cjis_case_number,x.charge_id,
                    x.charge_count,x.charge_literal,x.bad_docket_count,
                    x.first_bad_received_date,x.last_bad_received_date
             from
                 (
                     select /*+ PARALLEL */
                         v.case_defendant_id,v.cjis_spn,v.cjis_case_number,v.charge_id,
                         min(v.charge_count) charge_count,
                         min(v.charge_literal) charge_literal,
                         count(distinct v.cjis_docket_id) bad_docket_count,
                         min(v.received_date) first_bad_received_date,
                         max(v.received_date) last_bad_received_date
                     from jisjdw.v_pnx2jis_bad_dkt v
                     group by v.case_defendant_id,v.cjis_spn, v.cjis_case_number,v.charge_id
                 ) x
         ) b, -- affected charges already identified
         (
             select /*+ PARALLEL */ distinct hh.charge_id activity_key, 1,1,1,1,1
             from JISJDW.CHARGE_HIST hh
             where (
                 CHANGED_COLUMNS LIKE '%LOCATION%'
                     or CHANGED_COLUMNS LIKE '%STATUS%'
                     or CHANGED_COLUMNS LIKE '%BOND_AMT%'
                 )
               and CREATE_DATE_TIME >= TO_DATE('2026-08-18 00:00', 'yyyy-mm-dd hh24:mi')
               and CREATE_DATE_TIME <= TO_DATE('2026-09-01 00:00', 'yyyy-mm-dd hh24:mi')
         ) la, -- charges with location changed
         (
             select --all docket entries potentially mistakenly created by the interface
                 /*+ PARALLEL */
                    d.charge_id,
                    count(*) docket_count_since_start,
                    sum(case
                            when upper(trim(d.create_user_id)) in ('SYSTEMA','PNX2JIS')
                                then 1 else 0
                        end) machine_docket_count,
                    sum(case
                            when nvl(upper(trim(d.create_user_id)),'~') not in ('SYSTEMA','PNX2JIS')
                                then 1 else 0
                        end) nonmachine_docket_count,
                    min(d.create_date_time) first_docket_created,
                    max(d.create_date_time) last_docket_created
             from jisjdw.cjis_docket d
             where d.create_date_time >= to_date('2026-08-18','YYYY-MM-DD')
               and d.create_date_time <= sysdate
             group by d.charge_id
         ) ds, -- potentially bad dockets
         (
             select *
             from (select
                       row_number() over (partition by h.CHARGE_NUMBER order by h.CHARGE_HIST_ID) rank_order
                    , h.CHARGE_ID
                        , h.OLD_BOND_AMT
                        , h.OLD_LOCATION
                        , h.OLD_STATUS
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
         ) last_charge_hist
    where c.charge_id=b.charge_id
      and last_charge_hist.CHARGE_ID(+) = c.charge_id --outer join
      and length(Coalesce(last_charge_hist.OLD_LOCATION || last_charge_hist.OLD_STATUS || last_charge_hist.OLD_BOND_AMT, '')) > 0
      and la.activity_key = to_char(b.charge_id)
      and ds.charge_id = b.charge_id
      and ds.docket_count_since_start > 0
      and ds.machine_docket_count = ds.docket_count_since_start
      and ds.nonmachine_docket_count = 0
      and exists (
        SELECT
            cjis_case_number
        FROM audit_trail sys_only_changes
        WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
          and sys_only_changes.cjis_case_number = c.cjis_case_number
        GROUP BY
            cjis_case_number
        HAVING COUNT(*) =
               SUM(
                       CASE
                           WHEN activity_user_id IN ('JISJDW', 'SYSTEMA', 'PNX2JIS')
                               THEN 1
                           ELSE 0
                           END
               )

    )

    and not exists (
        select *
        from (
                 select
                     row_number() over(partition by CJIS_SPN order by INMATE_ID desc) latest
                ,i.*
                 from JISJDW.INMATE i
             ) "inmate_after"
        where coalesce(UPDATE_DATE_TIME, CREATE_DATE_TIME) > to_date('2026-08-18','YYYY-MM-DD')
          and latest = 1
          and c.CJIS_SPN = "inmate_after".CJIS_SPN
    )
)

select *
from target_set