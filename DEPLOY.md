# Netlify par live karne ke steps

Is package mein: login/register (asli SMS OTP, Supabase), booking + Razorpay payment, partner wallet/payout, admin panel.
Koi demo OTP ya demo payment nahi hai. Isliye Supabase aur Razorpay ka setup poora hona zaroori hai, warna login/payment kaam nahi karenge.

**Zaroori:** sirf zip ko Netlify Drop (drag & drop) par daalne se kaam nahi chalega, kyunki payment ke liye Netlify Functions chahiye.
Neeche wala GitHub tareeka sabse aasaan aur bharosemand hai.

## 1. Supabase (database + OTP)
1. supabase.com par project banayein.
2. SQL Editor mein ye files **is order mein** paste karke Run karein (supabase folder mein hain):
   `schema.sql`, `admin.sql`, `razorpay.sql`, `booking_payments.sql`, `commission.sql`, `discount_fix.sql`
   (`remove_demo.sql` sirf tab, agar aapne pehle purani SQL files chalayi thi.)
3. Authentication > Providers > Phone: ON karein aur SMS provider chunein (Twilio / MessageBird / Vonage / Textlocal; India ke liye DLT lagta hai).
4. Project Settings > API se **Project URL** aur **anon public key** copy karein.
5. `config.js` kholkar dono daalein. (WhatsApp/Instagram/Facebook bhi daal sakte hain; khali chhodne par wo buttons nahi dikhte.)

## 2. Razorpay
1. razorpay.com account. Pehle TEST mode: Settings > API Keys se Key ID aur Key Secret.
2. Settings > Payment Capture: Automatic.
3. Webhook (Settings > Webhooks): URL `https://AAPKI-SITE.netlify.app/.netlify/functions/razorpay-webhook`, events `payment.captured` aur `order.paid`, aur ek lamba random Secret (yaad rakhein). Site ka URL step 3 ke baad pata chalega; webhook baad mein bana sakte hain.

## 3. GitHub se Netlify
1. github.com par naya **private** repository banayein. Is zip ko khol kar uske andar ki saari files/folders repository mein upload karein (Add file > Upload files).
   `config.js` mein sirf anon key hoti hai (public hoti hai). Secret keys kabhi file mein na daalein.
2. app.netlify.com > Add new site > Import an existing project > GitHub > apni repository chunein. Build command khali, publish directory `.` (netlify.toml se aa jaata hai). Deploy se pehle "Environment variables" mein ye 5 daalein:
   `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` (Supabase > Settings > API > service_role),
   `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`
3. Deploy dabayein. Agar "secrets scanning" ka error aaye to Site settings > Environment variables mein `SECRETS_SCAN_OMIT_KEYS` = `SUPABASE_URL` daal dein.
4. Site chalne ke baad Razorpay webhook (2.3) bana dein, aur Netlify mein variables badalne par hamesha "Trigger deploy" karein.

## 4. Admin banana aur test
1. Site par apne number se register karein, phir SQL Editor mein: `update public.profiles set is_admin = true where mobile = 'APNA-10-DIGIT';`
2. `/admin.html` kholein. Settings > "Go-live check" dabayein.
3. **TEST_CHECKLIST.md** poora chalayein (Razorpay TEST keys par). Test OTP numbers Supabase Phone provider mein daalna mat bhoolein, aur live se pehle hata dein.

## 5. Live
`LIVE_CHECKLIST.md` (Razorpay KYC, live keys, live webhook, policy pages, custom domain).
