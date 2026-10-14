-- Referral discount ko surakshit aur sasta banana. commission.sql ke BAAD Supabase SQL Editor mein run karein.
--
-- Naye niyam:
--  1. Discount = fare ka 50%, lekin ek booking par zyada se zyada max_discount (default Rs 150). Admin Settings mein badal sakte hain.
--  2. Refer karne wale ko reward tab milta hai jab dost ki PEHLI booking POORI ho jaaye (pehle booking banate hi mil jaata tha: galat tha).
--  3. Booking cancel ho (customer ya admin) to customer ka discount wapas mil jaata hai.
--  4. Ek customer ke paas zyada se zyada 3 reward credits jama ho sakte hain.
--  5. Admin ke paas poora referral discount band karne ka switch hai (referral_discount_on).

insert into public.app_settings values ('max_discount','150') on conflict do nothing;
insert into public.app_settings values ('referral_discount_on','true') on conflict do nothing;
alter table public.jobs add column if not exists disc_kind text;

create or replace function public.public_config() returns jsonb
language sql security definer stable set search_path=public as $$
  select jsonb_build_object(
    'max_discount', coalesce((select value::int from app_settings where key='max_discount'),150),
    'referral_on', coalesce((select value from app_settings where key='referral_discount_on'),'true') = 'true')
$$;
revoke execute on function public.public_config() from public, anon;
grant execute on function public.public_config() to authenticated;

-- Internal: cancel hone par discount wapas
create or replace function public._restore_disc(p_uid uuid, p_kind text) returns void
language plpgsql security definer set search_path=public as $$
begin
  if p_kind = 'first' then update profiles set disc_available = true where id = p_uid;
  elsif p_kind = 'credit' then update profiles set reward_credits = least(reward_credits + 1, 3) where id = p_uid; end if;
end $$;
revoke execute on function public._restore_disc(uuid,text) from public, anon, authenticated;

create or replace function public.create_job(p_kind text,p_role text,p_venue text,p_city text,p_address text,
  p_date date,p_slot text,p_hours int,p_guests int,p_notes text,p_budget int,p_extra int)
returns jsonb language plpgsql security definer set search_path=public as $$
declare me profiles; fare int; pay int; disc boolean := false; dk text; dmax int; dsc int := 0; jid uuid; ex int := coalesce(p_extra,0);
begin
  select * into me from profiles where id = auth.uid();
  if me.id is null then raise exception 'Login zaroori hai'; end if;
  if me.role = 'Partner' then raise exception 'Partner booking nahi kar sakte'; end if;
  if p_kind not in ('home','venue') or (p_kind='venue' and me.role <> 'Owner') then raise exception 'Booking type sahi nahi hai'; end if;
  if p_role not in ('Waiter','Bartender','Barista','Chef','Housekeeping','GRE','Helper','Security') then raise exception 'Post sahi nahi hai'; end if;
  if p_date is null or p_date < current_date then raise exception 'Date sahi nahi hai'; end if;
  if ex < 0 or ex > 2000 or ex % 100 <> 0 then raise exception 'Custom amount sahi nahi hai'; end if;
  if p_kind='home' and p_role='Waiter' then
    fare := 400 + greatest(0, coalesce(p_hours,4)-4)*100 + ex;
  elsif p_kind='home' and p_role='Housekeeping' then
    fare := greatest(2, coalesce(p_hours,2))*150 + ex;
  else fare := coalesce(p_budget,0); end if;
  if fare < 100 or fare > 100000 then raise exception 'Amount sahi nahi hai'; end if;
  pay := fare;
  if p_kind = 'home' and me.role = 'Customer' and (me.disc_available or me.reward_credits > 0)
     and coalesce((select value from app_settings where key='referral_discount_on'),'true') = 'true' then
    dmax := coalesce((select value::int from app_settings where key='max_discount'),150);
    dsc := least(round(fare/2.0)::int, dmax);
    if dsc > 0 then
      disc := true; pay := fare - dsc;
      if me.disc_available then dk := 'first'; update profiles set disc_available = false where id = me.id;
      else dk := 'credit'; update profiles set reward_credits = reward_credits - 1 where id = me.id; end if;
    end if;
  end if;
  insert into jobs(owner_id,kind,role,venue,city,address,job_date,slot,hours,guests,notes,pay,customer_pays,discounted,disc_kind)
  values(me.id,p_kind,p_role,left(p_venue,60),left(p_city,40),left(p_address,160),p_date,left(p_slot,40),p_hours,p_guests,left(p_notes,160),fare,pay,disc,dk)
  returning jobs.id into jid;
  return jsonb_build_object('id',jid,'fare',fare,'customer_pays',pay,'discounted',disc,'discount',dsc);
end $$;

-- Customer ke cancel par discount wapas (baaki rules pehle jaise)
create or replace function public.cancel_booking_server(p_job uuid, p_uid uuid) returns jsonb
language plpgsql security definer set search_path=public as $$
declare j jobs;
begin
  select * into j from jobs where id = p_job for update;
  if not found or j.owner_id is distinct from p_uid then raise exception 'Booking nahi mili'; end if;
  if j.status not in ('Open','Accepted') then raise exception 'Ye booking cancel nahi ho sakti'; end if;
  if j.status = 'Accepted' and j.job_date <= current_date then
    raise exception 'Booking ke din ya uske baad cancel nahi ho sakti. Support se sampark karein';
  end if;
  update jobs set status='Cancelled', pay_status = case when pay_status='paid' then 'refund_due' else pay_status end where id = p_job;
  if j.discounted then perform public._restore_disc(j.owner_id, j.disc_kind); end if;
  return jsonb_build_object('pay_status', case when j.pay_status='paid' then 'refund_due' else j.pay_status end);
end $$;

create or replace function public.admin_cancel_job(p_id uuid) returns void
language plpgsql security definer set search_path=public as $$
declare j jobs;
begin
  perform public._need_admin();
  select * into j from jobs where id = p_id for update;
  if not found or j.status not in ('Open','Accepted') then raise exception 'Cancel nahi ho saka'; end if;
  update jobs set status='Cancelled', pay_status = case when pay_status='paid' then 'refund_due' else pay_status end where id = p_id;
  if j.discounted then perform public._restore_disc(j.owner_id, j.disc_kind); end if;
  insert into admin_log(admin_id,action,detail) values(auth.uid(),'cancel_job',p_id::text);
end $$;

-- Booking poori hone par: partner ko (fare - fee), aur refer karne wale ko reward (dost ki pehli paid booking par)
create or replace function public.confirm_complete(p_id uuid) returns void
language plpgsql security definer set search_path=public as $$
declare j jobs; cr int; ow profiles;
begin
  select * into j from jobs where id = p_id for update;
  if not found or j.owner_id is distinct from auth.uid() or j.status <> 'Accepted' then raise exception 'Booking confirm nahi ho sakti'; end if;
  update jobs set status='Completed' where id = p_id;
  if j.pay_status = 'paid' then
    cr := j.pay - j.fee_amt;
    update profiles set wallet = wallet + cr where id = j.partner_id;
    insert into wallet_tx(user_id,type,note,amount)
    values(j.partner_id,'Payments','Booking: '||j.role||' ('||j.job_date||')'||case when j.fee_pct > 0 then ' - '||j.fee_pct||'% platform fee' else '' end, cr);
    select * into ow from profiles where id = j.owner_id;
    if ow.referred_by is not null and not ow.reward_given then
      update profiles set reward_given = true where id = ow.id;
      update profiles set reward_credits = least(reward_credits + 1, 3) where id = ow.referred_by;
    end if;
  end if;
end $$;

-- Admin hisaab: discount ka kharch aur baaki discounts
create or replace function public.admin_revenue() returns jsonb
language plpgsql security definer set search_path=public as $$
declare ft int; fm int; bm numeric; dc numeric; sb numeric; pd int;
begin
  perform public._need_admin();
  select coalesce(sum(fee_amt),0),
         coalesce(sum(fee_amt) filter (where job_date >= date_trunc('month',current_date)),0),
         coalesce(sum(customer_pays - (pay - fee_amt)),0),
         coalesce(sum(pay - customer_pays),0)
    into ft, fm, bm, dc from jobs where status = 'Completed' and pay_status = 'paid';
  select coalesce(sum(amount),0)/100.0 into sb from payments where purpose = 'subscription' and status = 'paid';
  select coalesce(sum(reward_credits),0) + count(*) filter (where disc_available) into pd from profiles;
  return jsonb_build_object('fee_total',ft,'fee_month',fm,'booking_margin',bm,'discount_cost',dc,'subs',sb,'net',bm+sb,'pending_discounts',pd);
end $$;

create or replace function public.admin_set_setting(p_key text, p_value text) returns void
language plpgsql security definer set search_path=public as $$
begin
  perform public._need_admin();
  if p_key = 'referral_discount_on' and p_value in ('true','false') then null;
  elsif p_key = 'commission_pct' and (case when p_value ~ '^[0-9]{1,2}$' then p_value::int <= 30 else false end) then null;
  elsif p_key = 'max_discount' and (case when p_value ~ '^[0-9]{1,4}$' then p_value::int <= 2000 else false end) then null;
  else raise exception 'Setting sahi nahi hai'; end if;
  insert into app_settings values (p_key, p_value) on conflict (key) do update set value = excluded.value;
  insert into admin_log(admin_id,action,detail) values(auth.uid(),'setting',p_key||' = '||p_value);
end $$;
