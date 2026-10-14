-- StaffWale verify.sql: SQL Editor mein ek-ek section chalakar dekhein. Ye sirf PADHTA hai, kuch badalta nahi.

-- 1) Har table par RLS ON hona chahiye (rls = true)
select c.relname as table_name, c.relrowsecurity as rls
from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' order by 1;

-- 2) Zaroori functions maujood hain? (exists = true sab par)
select f as function_name,
       exists(select 1 from pg_proc where pronamespace='public'::regnamespace and proname=f) as exists
from unnest(array['create_job','accept_job','partner_cancel','confirm_complete','my_orders','my_partner_jobs','staff_bookings',
  'busy_dates','staff_phone','save_bank','request_payout','add_review','apply_payment','cancel_booking_server',
  'mark_refunded','public_config','is_admin','admin_stats','admin_users','admin_set_verified',
  'admin_grant_subscription','admin_payouts','admin_mark_payout','admin_jobs','admin_cancel_job','admin_reviews',
  'admin_delete_review','admin_set_setting','admin_settings','admin_log_list','admin_payments','admin_revenue','_fee_pct','_restore_disc']) as f
order by 1;

-- 3) Kaun kaun function chala sakta hai. anon_can SAB par false hona chahiye.
--    auth_can in par false hona chahiye: apply_payment, cancel_booking_server, mark_refunded, grant_subscription, owner_cancel, _restore_disc, _fee_pct
select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon_can,
       has_function_privilege('authenticated', p.oid, 'execute') as auth_can
from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prokind = 'f' order by 1;

-- 4) Table permissions: anon ko kuch nahi; authenticated ko sirf SELECT (aur profiles ke kuch columns par UPDATE)
select grantee, table_name, privilege_type
from information_schema.role_table_grants
where table_schema = 'public' and grantee in ('anon','authenticated') order by 2,1,3;
select grantee, table_name, column_name, privilege_type
from information_schema.role_column_grants
where table_schema = 'public' and grantee in ('anon','authenticated') and privilege_type = 'UPDATE' order by 2,3;
-- Expect: sirf profiles ke name, city, age, vehicle, post, exp par UPDATE.

-- 5) Policies
select tablename, policyname, cmd from pg_policies where schemaname = 'public' order by 1,2;

-- 6) Settings
select * from app_settings order by 1;

-- 6b) Demo functions nahi honi chahiye (0 rows aani chahiye)
select proname from pg_proc where pronamespace='public'::regnamespace and proname in ('subscribe_demo','booking_pay_demo');

-- 7) Admin kaun hain (sirf aap ke apne numbers hone chahiye)
select mobile, name, role from profiles where is_admin;

-- ===== Test ke BAAD paison ka hisaab (sab sahi to ye barabar hone chahiye) =====

-- 8) Har partner ka wallet = uski wallet history ka jod (difference 0 hona chahiye)
select p.mobile, p.wallet, coalesce(sum(w.amount),0) as ledger, p.wallet - coalesce(sum(w.amount),0) as difference
from profiles p left join wallet_tx w on w.user_id = p.id
where p.role = 'Partner' group by p.id order by 1;

-- 9) Razorpay se aaya booking paisa = paid/refund wali bookings ka customer_pays (difference 0)
select
  (select coalesce(sum(amount),0)/100.0 from payments where purpose='booking' and status='paid') as razorpay_booking_total,
  (select coalesce(sum(customer_pays),0) from jobs where kind='home' and pay_status in ('paid','refund_due','refunded')) as jobs_total;

-- 10) Har ghar par booking ka haal: status, payment aur discount
select j.created_at::date as created, j.role, j.job_date, j.status, j.pay_status, j.pay as fare, j.customer_pays, j.discounted,
       j.fee_pct, j.fee_amt, (select status from payments p where p.job_id = j.id order by p.id desc limit 1) as payment_row
from jobs j where j.kind = 'home' order by j.created_at;

-- 11) Partners ke wallet ka kul balance (aapki zimmedari) aur pending payouts
select (select coalesce(sum(wallet),0) from profiles) as partner_wallets_total,
       (select coalesce(sum(amount),0) from payouts where status='Processing') as payouts_pending;

-- 12) Galat haal wali bookings (koi row aaye to mujhe bhejein).
--     Dhyan: Open + unpaid normal hai (wo "Payment baaki" wali booking hai, partners ko nahi dikhti).
select id, status, pay_status from jobs
where kind = 'home' and (
      (status in ('Accepted','Completed') and pay_status = 'unpaid')      -- bina payment accept/complete nahi honi chahiye
   or (status = 'Cancelled' and pay_status = 'paid'));                    -- cancel + paid ho to refund_due/refunded hona chahiye

-- 13) Admin ke actions ka record
select created_at, action, detail from admin_log order by created_at desc limit 30;
