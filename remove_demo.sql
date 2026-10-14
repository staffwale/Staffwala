-- Sirf tab chalayein jab aapne pehle purani SQL files (demo wali) run kar di thi. Naye install par zarurat nahi.
-- Demo/free-payment ke raaste hamesha ke liye hata deta hai. Dobara chalane se koi nuksaan nahi.
drop function if exists public.subscribe_demo();
drop function if exists public.booking_pay_demo(uuid);
delete from public.app_settings where key = 'demo_payments';
