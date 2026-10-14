-- Booking payments + refunds. schema.sql, admin.sql, razorpay.sql ke BAAD run karein.
-- Note: agar aapke paas pehle se test bookings (jobs) hain, to unhe free rakhne ke liye ek baar chalayein:
--   update public.jobs set pay_status = 'na' where status in ('Open','Accepted','Completed');   (sirf is script ke pehli baar chalne ke baad, pehle se bani jobs ke liye)

alter table public.jobs add column if not exists pay_status text not null default 'unpaid'
  check (pay_status in ('unpaid','paid','refund_due','refunded','na'));
alter table public.jobs add column if not exists payment_id text;
alter table public.jobs add column if not exists refund_id text;
alter table public.payments add column if not exists job_id uuid references public.jobs(id);

-- Owner ke venue jobs mein payment nahi liya jaata
create or replace function public.jobs_set_paystatus() returns trigger language plpgsql as $$
begin if new.kind = 'venue' then new.pay_status := 'na'; end if; return new; end $$;
drop trigger if exists jobs_paystatus on public.jobs;
create trigger jobs_paystatus before insert on public.jobs for each row execute function public.jobs_set_paystatus();
update public.jobs set pay_status = 'na' where kind = 'venue' and pay_status = 'unpaid';

-- Partners ko sirf PAID (ya venue) bookings dikhti hain
create or replace view public.jobs_open as
select j.id, j.kind, j.role,
       case when j.kind='home' then 'Ghar par' else coalesce(j.venue,'') end as venue,
       j.city, j.job_date, j.slot, j.hours, j.guests, j.pay, j.created_at
from public.jobs j
where j.status='Open' and j.pay_status in ('paid','na') and j.job_date >= current_date;

create or replace function public.accept_job(p_id uuid) returns void
language plpgsql security definer set search_path=public as $$
declare me profiles; j jobs; n int;
begin
  select * into me from profiles where id = auth.uid();
  if me.role is distinct from 'Partner' then raise exception 'Sirf Partner accept kar sakte hain'; end if;
  select * into j from jobs where id = p_id for update;
  if not found or j.status <> 'Open' or j.pay_status not in ('paid','na') then raise exception 'Ye booking ab available nahi hai'; end if;
  select count(*) into n from jobs where partner_id=me.id and status='Accepted' and job_date=j.job_date and slot is not distinct from j.slot;
  if n > 0 then raise exception 'Is date aur slot par aapki booking pehle se hai'; end if;
  update jobs set status='Accepted', partner_id=me.id where id=p_id;
end $$;

-- Payment aane par: subscription ya booking ko paid mark karo (dobara chalane par double nahi hota)
create or replace function public.apply_payment(p_order text, p_payment text) returns boolean
language plpgsql security definer set search_path=public as $$
declare pm payments;
begin
  select * into pm from payments where order_id = p_order for update;
  if not found or pm.status = 'paid' then return false; end if;
  update payments set status='paid', payment_id=p_payment, paid_at=now() where id = pm.id;
  if pm.purpose = 'subscription' then
    update profiles set sub_until = greatest(coalesce(sub_until,current_date),current_date) + 30 where id = pm.user_id;
  elsif pm.purpose = 'booking' then
    -- booking pehle hi cancel ho chuki ho to paisa wapas dena padega
    update jobs set payment_id = p_payment, pay_status = case when status = 'Open' then 'paid' else 'refund_due' end
    where id = pm.job_id and pay_status = 'unpaid';
  end if;
  return true;
end $$;

-- Cancel rules (sirf server function ke through): Open = poora refund; Accepted = booking ke din se kam se kam 1 din pehle tak
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
  return jsonb_build_object('pay_status', case when j.pay_status='paid' then 'refund_due' else j.pay_status end);
end $$;

create or replace function public.mark_refunded(p_job uuid, p_refund text) returns void
language sql security definer set search_path=public as $$
  update jobs set pay_status='refunded', refund_id=p_refund where id = p_job and pay_status='refund_due';
$$;

create or replace function public.my_orders() returns jsonb
language sql security definer set search_path=public stable as $$
  select coalesce(jsonb_agg(jsonb_build_object('id',j.id,'kind',j.kind,'role',j.role,'venue',j.venue,'city',j.city,
    'address',j.address,'date',j.job_date,'slot',j.slot,'hours',j.hours,'guests',j.guests,'fare',j.pay,
    'pays',j.customer_pays,'disc',j.discounted,'status',j.status,'pay_status',j.pay_status,'pname',p.name) order by j.job_date desc, j.created_at desc),'[]'::jsonb)
  from jobs j left join profiles p on p.id = j.partner_id where j.owner_id = auth.uid();
$$;

create or replace function public.admin_jobs(p_status text) returns jsonb
language plpgsql security definer set search_path=public as $$
begin
  perform public._need_admin();
  return coalesce((select jsonb_agg(x) from (
    select jsonb_build_object('id',j.id,'kind',j.kind,'role',j.role,'venue',j.venue,'city',j.city,'address',j.address,
      'date',j.job_date,'slot',j.slot,'hours',j.hours,'pay',j.pay,'pays',j.customer_pays,'disc',j.discounted,'status',j.status,
      'pay_status',j.pay_status,'oname',o.name,'omobile',o.mobile,'pname',p.name,'pmobile',p.mobile) as x
    from jobs j join profiles o on o.id = j.owner_id left join profiles p on p.id = j.partner_id
    where coalesce(p_status,'') = ''
       or (p_status = 'RefundDue' and j.pay_status = 'refund_due')
       or (p_status <> 'RefundDue' and j.status = p_status)
    order by j.created_at desc limit 200) t),'[]'::jsonb);
end $$;

create or replace function public.admin_cancel_job(p_id uuid) returns void
language plpgsql security definer set search_path=public as $$
begin
  perform public._need_admin();
  update jobs set status='Cancelled', pay_status = case when pay_status='paid' then 'refund_due' else pay_status end
  where id = p_id and status in ('Open','Accepted');
  if not found then raise exception 'Cancel nahi ho saka'; end if;
  insert into admin_log(admin_id,action,detail) values(auth.uid(),'cancel_job',p_id::text);
end $$;

-- Grants: customer ab cancel seedha nahi kar sakta (refund ke liye server function se hi hoga)
revoke execute on function public.owner_cancel(uuid) from public, anon, authenticated;
revoke execute on function public.jobs_set_paystatus() from public, anon, authenticated;
revoke execute on function public.apply_payment(text,text) from public, anon, authenticated;
revoke execute on function public.cancel_booking_server(uuid,uuid) from public, anon, authenticated;
revoke execute on function public.mark_refunded(uuid,text) from public, anon, authenticated;
revoke execute on function public.accept_job(uuid) from public, anon;
revoke execute on function public.my_orders() from public, anon;
revoke execute on function public.admin_jobs(text) from public, anon;
revoke execute on function public.admin_cancel_job(uuid) from public, anon;
grant execute on function public.apply_payment(text,text) to service_role;
grant execute on function public.cancel_booking_server(uuid,uuid) to service_role;
grant execute on function public.mark_refunded(uuid,text) to service_role;
grant execute on function public.accept_job(uuid) to authenticated;
grant execute on function public.my_orders() to authenticated;
grant execute on function public.admin_jobs(text) to authenticated;
grant execute on function public.admin_cancel_job(uuid) to authenticated;
