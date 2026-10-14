-- StaffWale ADMIN setup. schema.sql ke BAAD Supabase SQL Editor mein run karein.

alter table public.profiles add column if not exists is_admin boolean not null default false;

create table if not exists public.admin_log(
  id bigint generated always as identity primary key,
  admin_id uuid, action text not null, detail text,
  created_at timestamptz not null default now());
alter table public.admin_log enable row level security;
revoke all on public.admin_log from anon, authenticated;

create or replace function public.is_admin() returns boolean
language sql security definer stable set search_path=public as $$
  select coalesce((select is_admin from profiles where id = auth.uid()), false)
$$;

create or replace function public._need_admin() returns void
language plpgsql security definer set search_path=public as $$
begin
  if not public.is_admin() then raise exception 'Sirf admin ke liye'; end if;
end $$;

create or replace function public.admin_stats() returns jsonb
language plpgsql security definer set search_path=public as $$
declare r jsonb;
begin
  perform public._need_admin();
  select jsonb_build_object(
    'users',(select count(*) from profiles),
    'customers',(select count(*) from profiles where role='Customer'),
    'partners',(select count(*) from profiles where role='Partner'),
    'owners',(select count(*) from profiles where role='Owner'),
    'verified',(select count(*) from profiles where role='Partner' and verified),
    'pending',(select count(*) from profiles where role='Partner' and not verified),
    'jobs_open',(select count(*) from jobs where status='Open'),
    'jobs_accepted',(select count(*) from jobs where status='Accepted'),
    'jobs_completed',(select count(*) from jobs where status='Completed'),
    'jobs_cancelled',(select count(*) from jobs where status='Cancelled'),
    'payouts_pending',(select count(*) from payouts where status='Processing'),
    'payouts_amount',(select coalesce(sum(amount),0) from payouts where status='Processing'),
    'wallet_total',(select coalesce(sum(wallet),0) from profiles),
    'subs_active',(select count(*) from profiles where sub_until >= current_date),
    'reviews',(select count(*) from reviews)) into r;
  return r;
end $$;

create or replace function public.admin_users(p_q text, p_role text, p_pending boolean) returns jsonb
language plpgsql security definer set search_path=public as $$
begin
  perform public._need_admin();
  return coalesce((select jsonb_agg(x) from (
    select jsonb_build_object('id',id,'name',name,'mobile',mobile,'role',role,'post',post,'city',city,
      'verified',verified,'sub_until',sub_until,'wallet',wallet,'created',created_at,'is_admin',is_admin) as x
    from profiles
    where (coalesce(p_role,'')='' or role=p_role)
      and (not coalesce(p_pending,false) or (role='Partner' and not verified))
      and (coalesce(p_q,'')='' or name ilike '%'||p_q||'%' or mobile like '%'||p_q||'%')
    order by created_at desc limit 200) t),'[]'::jsonb);
end $$;

create or replace function public.admin_set_verified(p_uid uuid, p_v boolean) returns void
language plpgsql security definer set search_path=public as $$
begin
  perform public._need_admin();
  update profiles set verified = p_v where id = p_uid and role = 'Partner';
  if not found then raise exception 'Partner nahi mila'; end if;
  insert into admin_log(admin_id,action,detail) values(auth.uid(),'verify',p_uid::text||' = '||p_v::text);
end $$;

create or replace function public.admin_grant_subscription(p_mobile text, p_days int) returns date
language plpgsql security definer set search_path=public as $$
declare d date;
begin
  perform public._need_admin();
  if p_days < 1 or p_days > 365 then raise exception 'Days 1 se 365 ke beech hone chahiye'; end if;
  update profiles set sub_until = greatest(coalesce(sub_until,current_date),current_date) + p_days
  where mobile = p_mobile and role in ('Customer','Owner') returning sub_until into d;
  if d is null then raise exception 'Customer/Owner nahi mila'; end if;
  insert into admin_log(admin_id,action,detail) values(auth.uid(),'subscription',p_mobile||' +'||p_days||' din');
  return d;
end $$;

create or replace function public.admin_payouts(p_status text) returns jsonb
language plpgsql security definer set search_path=public as $$
begin
  perform public._need_admin();
  return coalesce((select jsonb_agg(x) from (
    select jsonb_build_object('id',po.id,'amount',po.amount,'status',po.status,'created',po.created_at,
      'name',p.name,'mobile',p.mobile,'holder',b.holder,'account',b.account,'ifsc',b.ifsc,'upi',b.upi) as x
    from payouts po join profiles p on p.id = po.user_id left join bank_details b on b.user_id = po.user_id
    where (coalesce(p_status,'')='' or po.status = p_status)
    order by po.created_at desc limit 200) t),'[]'::jsonb);
end $$;

create or replace function public.admin_mark_payout(p_id bigint, p_status text) returns void
language plpgsql security definer set search_path=public as $$
declare po payouts;
begin
  perform public._need_admin();
  if p_status not in ('Paid','Rejected') then raise exception 'Status sahi nahi hai'; end if;
  select * into po from payouts where id = p_id for update;
  if not found or po.status <> 'Processing' then raise exception 'Ye payout pehle hi process ho chuka hai'; end if;
  update payouts set status = p_status where id = p_id;
  if p_status = 'Rejected' then
    update profiles set wallet = wallet + po.amount where id = po.user_id;
    insert into wallet_tx(user_id,type,note,amount) values(po.user_id,'Payments','Payout reject hui - paisa wapas',po.amount);
  end if;
  insert into admin_log(admin_id,action,detail) values(auth.uid(),'payout',p_id::text||' '||p_status||' Rs '||po.amount);
end $$;

create or replace function public.admin_jobs(p_status text) returns jsonb
language plpgsql security definer set search_path=public as $$
begin
  perform public._need_admin();
  return coalesce((select jsonb_agg(x) from (
    select jsonb_build_object('id',j.id,'kind',j.kind,'role',j.role,'venue',j.venue,'city',j.city,'address',j.address,
      'date',j.job_date,'slot',j.slot,'hours',j.hours,'pay',j.pay,'pays',j.customer_pays,'disc',j.discounted,'status',j.status,
      'oname',o.name,'omobile',o.mobile,'pname',p.name,'pmobile',p.mobile) as x
    from jobs j join profiles o on o.id = j.owner_id left join profiles p on p.id = j.partner_id
    where (coalesce(p_status,'')='' or j.status = p_status)
    order by j.created_at desc limit 200) t),'[]'::jsonb);
end $$;

create or replace function public.admin_cancel_job(p_id uuid) returns void
language plpgsql security definer set search_path=public as $$
begin
  perform public._need_admin();
  update jobs set status='Cancelled' where id = p_id and status in ('Open','Accepted');
  if not found then raise exception 'Cancel nahi ho saka'; end if;
  insert into admin_log(admin_id,action,detail) values(auth.uid(),'cancel_job',p_id::text);
end $$;

create or replace function public.admin_reviews() returns jsonb
language plpgsql security definer set search_path=public as $$
begin
  perform public._need_admin();
  return coalesce((select jsonb_agg(x) from (
    select jsonb_build_object('id',id,'name',name,'stars',stars,'body',body,'created',created_at) as x
    from reviews order by created_at desc limit 200) t),'[]'::jsonb);
end $$;

create or replace function public.admin_delete_review(p_id bigint) returns void
language plpgsql security definer set search_path=public as $$
begin
  perform public._need_admin();
  delete from reviews where id = p_id;
  insert into admin_log(admin_id,action,detail) values(auth.uid(),'delete_review',p_id::text);
end $$;

create or replace function public.admin_set_setting(p_key text, p_value text) returns void
language plpgsql security definer set search_path=public as $$
begin
  perform public._need_admin();
  if p_key <> 'commission_pct' or p_value !~ '^[0-9]{1,2}$' then raise exception 'Setting sahi nahi hai'; end if;
  update app_settings set value = p_value where key = p_key;
  insert into admin_log(admin_id,action,detail) values(auth.uid(),'setting',p_key||' = '||p_value);
end $$;

create or replace function public.admin_log_list() returns jsonb
language plpgsql security definer set search_path=public as $$
begin
  perform public._need_admin();
  return coalesce((select jsonb_agg(x) from (
    select jsonb_build_object('action',l.action,'detail',l.detail,'created',l.created_at,'admin',p.name) as x
    from admin_log l left join profiles p on p.id = l.admin_id order by l.created_at desc limit 50) t),'[]'::jsonb);
end $$;

-- Sirf login kiye hue users ye functions call kar sakte hain; andar se admin check hota hai.
revoke execute on function public.is_admin() from public, anon;
revoke execute on function public._need_admin() from public, anon;
revoke execute on function public.admin_stats() from public, anon;
revoke execute on function public.admin_users(text,text,boolean) from public, anon;
revoke execute on function public.admin_set_verified(uuid,boolean) from public, anon;
revoke execute on function public.admin_grant_subscription(text,int) from public, anon;
revoke execute on function public.admin_payouts(text) from public, anon;
revoke execute on function public.admin_mark_payout(bigint,text) from public, anon;
revoke execute on function public.admin_jobs(text) from public, anon;
revoke execute on function public.admin_cancel_job(uuid) from public, anon;
revoke execute on function public.admin_reviews() from public, anon;
revoke execute on function public.admin_delete_review(bigint) from public, anon;
revoke execute on function public.admin_set_setting(text,text) from public, anon;
revoke execute on function public.admin_log_list() from public, anon;
grant execute on function public.is_admin() to authenticated;
grant execute on function public._need_admin() to authenticated;
grant execute on function public.admin_stats() to authenticated;
grant execute on function public.admin_users(text,text,boolean) to authenticated;
grant execute on function public.admin_set_verified(uuid,boolean) to authenticated;
grant execute on function public.admin_grant_subscription(text,int) to authenticated;
grant execute on function public.admin_payouts(text) to authenticated;
grant execute on function public.admin_mark_payout(bigint,text) to authenticated;
grant execute on function public.admin_jobs(text) to authenticated;
grant execute on function public.admin_cancel_job(uuid) to authenticated;
grant execute on function public.admin_reviews() to authenticated;
grant execute on function public.admin_delete_review(bigint) to authenticated;
grant execute on function public.admin_set_setting(text,text) to authenticated;
grant execute on function public.admin_log_list() to authenticated;

-- Apne account ko admin banane ke liye (pehle app mein register karein), apna 10 digit number daalkar chalayein:
-- update public.profiles set is_admin = true where mobile = '9XXXXXXXXX';
