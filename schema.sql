-- StaffWale schema for Supabase. SQL Editor mein poora paste karke Run karein.

create table if not exists public.app_settings(key text primary key, value text not null);

create table if not exists public.profiles(
  id uuid primary key references auth.users(id) on delete cascade,
  mobile text unique not null,
  name text not null default '',
  role text not null default 'Customer' check (role in ('Customer','Partner','Owner')),
  post text, city text, age int, vehicle text,
  exp int not null default 0,
  ref_code text unique not null,
  referred_by uuid references public.profiles(id),
  disc_available boolean not null default false,
  reward_credits int not null default 0,
  reward_given boolean not null default false,
  sub_until date,
  wallet int not null default 0,
  verified boolean not null default false,
  created_at timestamptz not null default now());

create table if not exists public.jobs(
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id),
  kind text not null check (kind in ('home','venue')),
  role text not null, venue text, city text not null, address text,
  job_date date not null, slot text, hours int, guests int, notes text,
  pay int not null,
  customer_pays int not null,
  discounted boolean not null default false,
  status text not null default 'Open' check (status in ('Open','Accepted','Completed','Cancelled')),
  partner_id uuid references public.profiles(id),
  created_at timestamptz not null default now());
create index if not exists jobs_status_date on public.jobs(status, job_date);
create index if not exists jobs_partner on public.jobs(partner_id);

create table if not exists public.wallet_tx(
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null, note text, amount int not null,
  created_at timestamptz not null default now());

create table if not exists public.payouts(
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  amount int not null, dest text,
  status text not null default 'Processing',
  created_at timestamptz not null default now());

create table if not exists public.bank_details(
  user_id uuid primary key references public.profiles(id) on delete cascade,
  holder text, account text, ifsc text, upi text);

create table if not exists public.reviews(
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  stars int not null check (stars between 1 and 5),
  body text not null,
  created_at timestamptz not null default now());

-- Naya user (OTP verify ke baad) -> profile apne aap ban jaati hai
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path=public as $$
declare m jsonb := coalesce(new.raw_user_meta_data,'{}'::jsonb); r text; rf uuid; code text;
begin
  r := case when m->>'role' in ('Partner','Owner','Customer') then m->>'role' else 'Customer' end;
  code := upper(trim(coalesce(m->>'ref','')));
  if code <> '' and r = 'Customer' then
    select id into rf from public.profiles where ref_code = code and role = 'Customer';
  end if;
  insert into public.profiles(id,mobile,name,role,post,city,ref_code,referred_by,disc_available)
  values(new.id, right(coalesce(new.phone,''),10), left(coalesce(m->>'name',''),50), r,
         nullif(m->>'post',''), left(coalesce(m->>'city',''),40),
         'SW'||upper(substr(md5(random()::text||new.id::text),1,5)), rf, rf is not null);
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Public views (phone/address kabhi nahi dikhte)
create or replace view public.jobs_open as
select j.id, j.kind, j.role,
       case when j.kind='home' then 'Ghar par' else coalesce(j.venue,'') end as venue,
       j.city, j.job_date, j.slot, j.hours, j.guests, j.pay, j.created_at
from public.jobs j where j.status='Open' and j.job_date >= current_date;

create or replace view public.staff_public as
select p.id, p.name, p.post, p.city, p.exp, p.verified,
       left(p.mobile,2)||'******'||right(p.mobile,2) as mask,
       (select count(*) from public.jobs j where j.partner_id=p.id and j.status='Completed') as done,
       (select count(*) from public.jobs j where j.partner_id=p.id and j.status='Accepted') as upcoming
from public.profiles p where p.role='Partner' and p.name <> '';

-- Booking banana: price, hourly rate aur 50% referral discount SERVER par calculate hota hai
create or replace function public.create_job(p_kind text,p_role text,p_venue text,p_city text,p_address text,
  p_date date,p_slot text,p_hours int,p_guests int,p_notes text,p_budget int,p_extra int)
returns jsonb language plpgsql security definer set search_path=public as $$
declare me profiles; fare int; pay int; disc boolean := false; jid uuid; ex int := coalesce(p_extra,0);
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
  if me.role='Customer' and (me.disc_available or me.reward_credits > 0) then
    disc := true; pay := round(fare/2.0);
    if me.disc_available then update profiles set disc_available=false where id=me.id;
    else update profiles set reward_credits=reward_credits-1 where id=me.id; end if;
  end if;
  if me.role='Customer' and me.referred_by is not null and not me.reward_given then
    update profiles set reward_given=true where id=me.id;
    update profiles set reward_credits=reward_credits+1 where id=me.referred_by;
  end if;
  insert into jobs(owner_id,kind,role,venue,city,address,job_date,slot,hours,guests,notes,pay,customer_pays,discounted)
  values(me.id,p_kind,p_role,left(p_venue,60),left(p_city,40),left(p_address,160),p_date,left(p_slot,40),p_hours,p_guests,left(p_notes,160),fare,pay,disc)
  returning jobs.id into jid;
  return jsonb_build_object('id',jid,'fare',fare,'customer_pays',pay,'discounted',disc);
end $$;

create or replace function public.accept_job(p_id uuid) returns void
language plpgsql security definer set search_path=public as $$
declare me profiles; j jobs; n int;
begin
  select * into me from profiles where id = auth.uid();
  if me.role is distinct from 'Partner' then raise exception 'Sirf Partner accept kar sakte hain'; end if;
  select * into j from jobs where id = p_id for update;
  if not found or j.status <> 'Open' then raise exception 'Ye booking ab available nahi hai'; end if;
  select count(*) into n from jobs where partner_id=me.id and status='Accepted' and job_date=j.job_date and slot is not distinct from j.slot;
  if n > 0 then raise exception 'Is date aur slot par aapki booking pehle se hai'; end if;
  update jobs set status='Accepted', partner_id=me.id where id=p_id;
end $$;

create or replace function public.partner_cancel(p_id uuid) returns void
language plpgsql security definer set search_path=public as $$
begin
  update jobs set status='Open', partner_id=null where id=p_id and partner_id=auth.uid() and status='Accepted';
  if not found then raise exception 'Cancel nahi ho saka'; end if;
end $$;

create or replace function public.owner_cancel(p_id uuid) returns void
language plpgsql security definer set search_path=public as $$
begin
  update jobs set status='Cancelled' where id=p_id and owner_id=auth.uid() and status in ('Open','Accepted');
  if not found then raise exception 'Cancel nahi ho saka'; end if;
end $$;

-- Customer confirm kare ki kaam ho gaya -> partner ke wallet mein paisa
create or replace function public.confirm_complete(p_id uuid) returns void
language plpgsql security definer set search_path=public as $$
declare j jobs;
begin
  select * into j from jobs where id = p_id for update;
  if not found or j.owner_id is distinct from auth.uid() or j.status <> 'Accepted' then raise exception 'Booking confirm nahi ho sakti'; end if;
  update jobs set status='Completed' where id = p_id;
  update profiles set wallet = wallet + j.pay where id = j.partner_id;
  insert into wallet_tx(user_id,type,note,amount) values(j.partner_id,'Payments','Booking: '||j.role||' ('||j.job_date||')',j.pay);
end $$;

create or replace function public.my_orders() returns jsonb
language sql security definer set search_path=public stable as $$
  select coalesce(jsonb_agg(jsonb_build_object('id',j.id,'kind',j.kind,'role',j.role,'venue',j.venue,'city',j.city,
    'address',j.address,'date',j.job_date,'slot',j.slot,'hours',j.hours,'guests',j.guests,'fare',j.pay,
    'pays',j.customer_pays,'disc',j.discounted,'status',j.status,'pname',p.name) order by j.job_date desc, j.created_at desc),'[]'::jsonb)
  from jobs j left join profiles p on p.id = j.partner_id where j.owner_id = auth.uid();
$$;

create or replace function public.my_partner_jobs() returns jsonb
language sql security definer set search_path=public stable as $$
  select coalesce(jsonb_agg(jsonb_build_object('id',j.id,'kind',j.kind,'role',j.role,'venue',j.venue,'city',j.city,
    'address',j.address,'date',j.job_date,'slot',j.slot,'hours',j.hours,'guests',j.guests,'pay',j.pay,
    'status',j.status,'cname',o.name,'cmobile',o.mobile) order by j.job_date desc),'[]'::jsonb)
  from jobs j join profiles o on o.id = j.owner_id where j.partner_id = auth.uid();
$$;

-- Staff ki booking history (customer ka naam short, number/address nahi)
create or replace function public.staff_bookings(pid uuid) returns jsonb
language sql security definer set search_path=public stable as $$
  select coalesce(jsonb_agg(jsonb_build_object('date',j.job_date,'status',j.status,
    'by',split_part(o.name,' ',1)||case when split_part(o.name,' ',2) <> '' then ' '||left(split_part(o.name,' ',2),1)||'.' else '' end,
    'role',j.role,'slot',j.slot,'hours',j.hours,'guests',j.guests,'kind',j.kind,'venue',j.venue) order by j.job_date desc),'[]'::jsonb)
  from jobs j join profiles o on o.id = j.owner_id
  where j.partner_id = pid and j.status in ('Accepted','Completed');
$$;

create or replace function public.busy_dates(p_date date) returns jsonb
language sql security definer set search_path=public stable as $$
  select coalesce(jsonb_agg(distinct partner_id),'[]'::jsonb) from jobs
  where job_date = p_date and status in ('Accepted','Completed') and partner_id is not null;
$$;

-- Staff ka number: sirf active subscription wale Customer/Owner ko
create or replace function public.staff_phone(pid uuid) returns text
language plpgsql security definer set search_path=public stable as $$
declare me profiles; res text;
begin
  select * into me from profiles where id = auth.uid();
  if me.id is null or me.role not in ('Customer','Owner') or me.sub_until is null or me.sub_until < current_date then return null; end if;
  select mobile into res from profiles where id = pid and role = 'Partner';
  return res;
end $$;

create or replace function public.grant_subscription(uid uuid, days int) returns void
language sql security definer set search_path=public as $$
  update profiles set sub_until = greatest(coalesce(sub_until,current_date),current_date) + days where id = uid;
$$;

create or replace function public.save_bank(p_holder text,p_account text,p_ifsc text,p_upi text) returns void
language plpgsql security definer set search_path=public as $$
begin
  if (select role from profiles where id=auth.uid()) is distinct from 'Partner' then raise exception 'Sirf Partner'; end if;
  if p_account !~ '^[0-9]{9,18}$' then raise exception 'Account number sahi nahi hai'; end if;
  if upper(p_ifsc) !~ '^[A-Z]{4}0[A-Z0-9]{6}$' then raise exception 'IFSC sahi nahi hai'; end if;
  insert into bank_details(user_id,holder,account,ifsc,upi)
  values(auth.uid(),left(p_holder,50),p_account,upper(p_ifsc),left(coalesce(p_upi,''),50))
  on conflict (user_id) do update set holder=excluded.holder, account=excluded.account, ifsc=excluded.ifsc, upi=excluded.upi;
end $$;

create or replace function public.request_payout(p_amount int) returns void
language plpgsql security definer set search_path=public as $$
declare me profiles; b bank_details; dest text;
begin
  select * into me from profiles where id = auth.uid() for update;
  if me.role is distinct from 'Partner' then raise exception 'Sirf Partner withdraw kar sakte hain'; end if;
  select * into b from bank_details where user_id = me.id;
  if not found then raise exception 'Pehle Bank Details save karein'; end if;
  if p_amount < 100 then raise exception 'Minimum withdraw 100 rupaye hai'; end if;
  if p_amount > me.wallet then raise exception 'Wallet mein sirf % rupaye hain', me.wallet; end if;
  dest := case when coalesce(b.upi,'') <> '' then 'UPI '||b.upi else 'Bank ****'||right(b.account,4)||' ('||b.ifsc||')' end;
  update profiles set wallet = wallet - p_amount where id = me.id;
  insert into payouts(user_id,amount,dest) values(me.id,p_amount,dest);
  insert into wallet_tx(user_id,type,note,amount) values(me.id,'Withdrawn','To '||dest,-p_amount);
end $$;

create or replace function public.add_review(p_stars int, p_body text) returns void
language plpgsql security definer set search_path=public as $$
begin
  if p_stars not between 1 and 5 or length(trim(coalesce(p_body,''))) = 0 then raise exception 'Review sahi nahi hai'; end if;
  insert into reviews(user_id,name,stars,body) select id,name,p_stars,left(trim(p_body),160) from profiles where id = auth.uid();
end $$;

-- Security: RLS on, direct table writes band
alter table public.profiles enable row level security;
alter table public.jobs enable row level security;
alter table public.wallet_tx enable row level security;
alter table public.payouts enable row level security;
alter table public.bank_details enable row level security;
alter table public.reviews enable row level security;
alter table public.app_settings enable row level security;

drop policy if exists p_own_sel on public.profiles;
create policy p_own_sel on public.profiles for select to authenticated using (id = auth.uid());
drop policy if exists p_own_upd on public.profiles;
create policy p_own_upd on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
drop policy if exists j_sel on public.jobs;
create policy j_sel on public.jobs for select to authenticated using (owner_id = auth.uid() or partner_id = auth.uid());
drop policy if exists w_sel on public.wallet_tx;
create policy w_sel on public.wallet_tx for select to authenticated using (user_id = auth.uid());
drop policy if exists po_sel on public.payouts;
create policy po_sel on public.payouts for select to authenticated using (user_id = auth.uid());
drop policy if exists b_sel on public.bank_details;
create policy b_sel on public.bank_details for select to authenticated using (user_id = auth.uid());
drop policy if exists r_sel on public.reviews;
create policy r_sel on public.reviews for select to authenticated using (true);

revoke all on all tables in schema public from anon, authenticated;
grant select on public.profiles, public.jobs, public.wallet_tx, public.payouts, public.bank_details, public.reviews to authenticated;
grant select on public.jobs_open, public.staff_public to authenticated;
grant update (name, city, age, vehicle, post, exp) on public.profiles to authenticated;

revoke execute on all functions in schema public from public, anon;
grant execute on all functions in schema public to authenticated;
revoke execute on function public.grant_subscription(uuid,int) from authenticated;
grant execute on function public.grant_subscription(uuid,int) to service_role;
