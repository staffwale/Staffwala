-- Platform commission. booking_payments.sql ke BAAD Supabase SQL Editor mein run karein.
-- Commission sirf online-paid ghar par bookings par lagta hai (partner ka fare 'pay' par %), aur accept ke samay partner ke liye fix ho jaata hai.
-- Default 10%. Admin panel > Settings mein badal sakte hain (0 se 30).

insert into public.app_settings values ('commission_pct','10') on conflict do nothing;
alter table public.jobs add column if not exists fee_pct int not null default 0;
alter table public.jobs add column if not exists fee_amt int not null default 0;

create or replace function public._fee_pct() returns int
language sql security definer stable set search_path=public as $$
  select coalesce((select value::int from app_settings where key='commission_pct'),0)
$$;
revoke execute on function public._fee_pct() from public, anon, authenticated;

-- Partners ko list mein fee ke baad ki kamai (net) dikhti hai
create or replace view public.jobs_open as
select j.id, j.kind, j.role,
       case when j.kind='home' then 'Ghar par' else coalesce(j.venue,'') end as venue,
       j.city, j.job_date, j.slot, j.hours, j.guests, j.pay, j.created_at,
       case when j.pay_status='paid' then public._fee_pct() else 0 end as fee_pct,
       j.pay - case when j.pay_status='paid' then round(j.pay * public._fee_pct() / 100.0)::int else 0 end as net
from public.jobs j
where j.status='Open' and j.pay_status in ('paid','na') and j.job_date >= current_date;

-- Accept ke samay fee fix (baad mein admin % badle to purani accepted booking par asar nahi)
create or replace function public.accept_job(p_id uuid) returns void
language plpgsql security definer set search_path=public as $$
declare me profiles; j jobs; n int; pct int;
begin
  select * into me from profiles where id = auth.uid();
  if me.role is distinct from 'Partner' then raise exception 'Sirf Partner accept kar sakte hain'; end if;
  select * into j from jobs where id = p_id for update;
  if not found or j.status <> 'Open' or j.pay_status not in ('paid','na') then raise exception 'Ye booking ab available nahi hai'; end if;
  select count(*) into n from jobs where partner_id=me.id and status='Accepted' and job_date=j.job_date and slot is not distinct from j.slot;
  if n > 0 then raise exception 'Is date aur slot par aapki booking pehle se hai'; end if;
  pct := case when j.pay_status = 'paid' then public._fee_pct() else 0 end;
  update jobs set status='Accepted', partner_id=me.id, fee_pct=pct, fee_amt=round(j.pay * pct / 100.0) where id = p_id;
end $$;

-- Customer confirm -> partner ke wallet mein (pay - fee). Sirf online paid booking par (venue jobs mein platform ke paas paisa aata hi nahi).
create or replace function public.confirm_complete(p_id uuid) returns void
language plpgsql security definer set search_path=public as $$
declare j jobs; cr int;
begin
  select * into j from jobs where id = p_id for update;
  if not found or j.owner_id is distinct from auth.uid() or j.status <> 'Accepted' then raise exception 'Booking confirm nahi ho sakti'; end if;
  update jobs set status='Completed' where id = p_id;
  if j.pay_status = 'paid' then
    cr := j.pay - j.fee_amt;
    update profiles set wallet = wallet + cr where id = j.partner_id;
    insert into wallet_tx(user_id,type,note,amount)
    values(j.partner_id,'Payments','Booking: '||j.role||' ('||j.job_date||')'||case when j.fee_pct > 0 then ' - '||j.fee_pct||'% platform fee' else '' end, cr);
  end if;
end $$;

create or replace function public.my_partner_jobs() returns jsonb
language sql security definer set search_path=public stable as $$
  select coalesce(jsonb_agg(jsonb_build_object('id',j.id,'kind',j.kind,'role',j.role,'venue',j.venue,'city',j.city,
    'address',j.address,'date',j.job_date,'slot',j.slot,'hours',j.hours,'guests',j.guests,'pay',j.pay,
    'pay_status',j.pay_status,'fee_pct',j.fee_pct,'fee_amt',j.fee_amt,
    'status',j.status,'cname',o.name,'cmobile',o.mobile) order by j.job_date desc),'[]'::jsonb)
  from jobs j join profiles o on o.id = j.owner_id where j.partner_id = auth.uid();
$$;

-- Admin: kamai ka hisaab
create or replace function public.admin_revenue() returns jsonb
language plpgsql security definer set search_path=public as $$
declare ft int; fm int; bm numeric; sb numeric;
begin
  perform public._need_admin();
  select coalesce(sum(fee_amt),0),
         coalesce(sum(fee_amt) filter (where job_date >= date_trunc('month',current_date)),0),
         coalesce(sum(customer_pays - (pay - fee_amt)),0)
    into ft, fm, bm from jobs where status = 'Completed' and pay_status = 'paid';
  select coalesce(sum(amount),0)/100.0 into sb from payments where purpose = 'subscription' and status = 'paid';
  return jsonb_build_object('fee_total',ft,'fee_month',fm,'booking_margin',bm,'subs',sb,'net',bm+sb);
end $$;

create or replace function public.admin_settings() returns jsonb
language plpgsql security definer set search_path=public as $$
begin
  perform public._need_admin();
  return coalesce((select jsonb_object_agg(key,value) from app_settings),'{}'::jsonb);
end $$;

create or replace function public.admin_set_setting(p_key text, p_value text) returns void
language plpgsql security definer set search_path=public as $$
begin
  perform public._need_admin();
  if p_key = 'commission_pct' and (case when p_value ~ '^[0-9]{1,2}$' then p_value::int <= 30 else false end) then null;
  else raise exception 'Setting sahi nahi hai'; end if;
  insert into app_settings values (p_key, p_value) on conflict (key) do update set value = excluded.value;
  insert into admin_log(admin_id,action,detail) values(auth.uid(),'setting',p_key||' = '||p_value);
end $$;

revoke execute on function public.admin_revenue() from public, anon;
revoke execute on function public.admin_settings() from public, anon;
grant execute on function public.admin_revenue() to authenticated;
grant execute on function public.admin_settings() to authenticated;
