select
    ch.cjis_spn,
    ch.cjis_case_number,
    ch.case_defendant_id,
    ch.charge_id,
    null OLD_STATUS,
    null OLD_LOCATION,
    null OLD_BOND_AMT
from jisjdw.charge ch,
     (select
          v.charge_id,
          count(distinct v.cjis_docket_id) bad_docket_count,
          min(v.received_date) first_bad_received_date,
          max(v.received_date) last_bad_received_date
      from jisjdw.v_pnx2jis_bad_dkt v
      group by v.charge_id
     ) vc
where ch.charge_id = vc.charge_id
  and exists (
    select 1 -- case was created before aug-18
    from cjis_docket d
    where d.charge_id = ch.charge_id
      and d.create_date_time < to_date('18-aug-2026'))
  and not exists ( -- not location, status, bond amount changes
    select 1
    from jisjdw.charge_hist h, jisjdw.v_pnx2jis_bad_dkt bd
    where bd.charge_id = ch.charge_id
      and h.charge_id = bd.charge_id
      and h.create_date_time between bd.received_date-(100/86400) and bd.received_date+(100/86400)
      and (
        (h.old_location <> h.new_location) or
        (h.old_location is null and h.new_location is not null) or
        (h.old_location is not null and h.new_location is null) or
        (h.old_status<>h.new_status) or
        (h.old_status is null and h.new_status is not null) or
        (h.old_status is not null and h.new_status is null) or
        (h.old_bond_amt<>h.new_bond_amt) or
        (h.old_bond_amt is null and h.new_bond_amt is not null) or
        (h.old_bond_amt is not null and h.new_bond_amt is null)
        ))
order by ch.cjis_spn,ch.cjis_case_number,ch.charge_id