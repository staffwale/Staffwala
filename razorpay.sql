-- Razorpay payments. schema.sql aur admin.sql ke BAAD Supabase SQL Editor mein run karein.

create table if not exists public.payments(
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  purpose text not null default 'subscription',
  amount int not null,                       -- paise
  order_id text unique not null,
  payment_id text,
  status text not null default 'created' check (status in ('created','paid')),
  created_at timestamptz not null default now(),
  paid_at timestamptz);
alter table public.payments enable row level security;
drop policy if exists pay_sel on public.payments;
create policy pay_sel on public.payments for select to authenticated using (user_id = auth.uid());
revoke all on public.payments from anon, authenticated;
grant select on public.payments to authenticated;

-- Sirf server (service_role) call kar sakta hai. Dobara call par double subscription nahi milta.
create or replace function public.apply_payment(p_order text, p_payment text) returns boolean
language plpgsql security definer set search_path=public as $$
declare pm payments;
begin
  select * into pm from payments where order_id = p_order for update;
  if not found or pm.status = 'paid' then return false; end if;
  update payments set status='paid', payment_id=p_payment, paid_at=now() where id = pm.id;
  if pm.purpose = 'subscription' then
    update profiles set sub_until = greatest(coalesce(sub_until,current_date),current_date) + 30 where id = pm.user_id;
  end if;
  return true;
end $$;
revoke execute on function public.apply_payment(text,text) from public, anon, authenticated;
grant execute on function public.apply_payment(text,text) to service_role;

create or replace function public.admin_payments() returns jsonb
language plpgsql security definer set search_path=public as $$
begin
  perform public._need_admin();
  return coalesce((select jsonb_agg(x) from (
    select jsonb_build_object('created',pm.created_at,'name',p.name,'mobile',p.mobile,'purpose',pm.purpose,
      'amount',pm.amount/100.0,'status',pm.status,'order',pm.order_id,'payment',pm.payment_id) as x
    from payments pm join profiles p on p.id = pm.user_id order by pm.created_at desc limit 200) t),'[]'::jsonb);
end $$;
revoke execute on function public.admin_payments() from public, anon;
grant execute on function public.admin_payments() to authenticated;
