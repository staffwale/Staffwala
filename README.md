# StaffWale (live package)
Netlify par live karne ke steps: **DEPLOY.md** se shuru karein. Is package mein koi demo OTP ya demo/free payment nahi hai: login asli SMS OTP se, payment sirf Razorpay se.


Accounts, OTP login, bookings, wallet, payouts, reviews aur staff directory ab Supabase database mein save hote hain.
Isse alag-alag phone/device par sab kuch sync rehta hai.

## Files
- index.html  – Login / Register (OTP)
- app.html + app.js – Poori website
- config.js   – Supabase keys + social links
- supabase/schema.sql – Database tables, security (RLS), server functions
- supabase/admin.sql  – Admin functions (schema.sql ke baad run karein)
- supabase/razorpay.sql – Payments table aur secure function (admin.sql ke baad)
- supabase/booking_payments.sql – Booking payment, cancel aur refund (razorpay.sql ke baad)
- netlify/functions + netlify/lib – Razorpay order, verify aur webhook
- terms.html, privacy.html, refund.html – policy templates (details bharein, vakeel se check karwayein)
- admin.html – Admin panel
- netlify.toml

## Setup (30-40 minute)
1. https://supabase.com par free project banayein.
2. Supabase > SQL Editor > New query: supabase/schema.sql ka poora text paste karke Run karein.
   Agar koi error aaye to error message save rakhein.
3. Supabase > Authentication > Providers > Phone: Enable karein aur SMS provider chunein
   (Twilio / MessageBird / Vonage / Textlocal). India mein SMS ke liye DLT registration lagta hai.
   TESTING ke liye: wahi Phone provider page par "Test phone numbers and OTPs" mein
   apna number aur ek fixed OTP daal sakte hain (jaise 919876543210=123456), SMS ke bina.
4. Supabase > Project Settings > API: "Project URL" aur "anon public" key ko config.js mein daalein.
   (service_role key kabhi config.js ya site mein na daalein.)
5. config.js mein apna WhatsApp number, Instagram, Facebook link daalein.
6. Site ko GitHub repo se Netlify par connect karein (ya Netlify CLI: `netlify deploy --prod`). Razorpay functions chalne ke liye drag & drop kaafi nahi hai.
7. Razorpay payments ke liye neeche wala section follow karein.

## Admin panel
1. schema.sql ke baad supabase/admin.sql bhi SQL Editor mein run karein.
2. Pehle website par apne number se register/login karein (koi bhi role).
3. SQL Editor mein chalayein: update public.profiles set is_admin = true where mobile = '9XXXXXXXXX';
4. Site ke /admin.html par jayein (admin ko app ke menu mein "Admin" link bhi dikhta hai).
Admin kya kar sakta hai: stats dekhna, partner verify/unverify, customer ko +30 din subscription, payout Paid/Reject
Admin check server par hota hai (is_admin), sirf URL jaanne se koi andar nahi ja sakta. Admin sirf 1-2 bharosemand log rakhein.

## Kya server par secure hai
- Price (waiter Rs 400 base + Rs 100 steps, housekeeping Rs 150/ghanta) aur 50% referral discount database function se calculate hota hai, browser se badla nahi ja sakta.
- Staff ka number sirf active Rs 99 subscription wale Customer/Owner ko milta hai (staff_phone function).
- Customer ka address sirf accept karne wale partner ko dikhta hai. Customer ka number kabhi public nahi hota.
- Wallet ka paisa sirf customer ke "Kaam ho gaya" confirm karne par partner ke wallet mein aata hai.

## Aapko khud karna hoga (admin)
- Partner verify aur payout ab admin.html se hote hain (upar Admin panel section dekhein).
- Bank details payout ke time admin ko dikhti hain, ye sensitive hain; zarurat ho to Supabase Vault/encryption lagayein.

## Abhi baaki (asli launch se pehle)
1. Razorpay KYC aur live keys: LIVE_CHECKLIST.md dekhein.
2. Partner ID verification: admin panel mein Verify button hai, lekin Aadhaar/photo upload nahi hai (verification aap call/video ya document se karein).
3. Terms, Privacy aur Refund pages mein [BRACKET] wali details bharein (naam, email, phone, address), aur vakeel se check karwayein.
4. OTP par spam rokne ke liye Supabase Auth ki rate-limit settings dekhein.
5. Payout abhi admin haath se bhejta hai (bank/UPI se), phir panel mein "Paid" dabata hai.

## Razorpay payments (Rs 99 subscription)
1. razorpay.sql ko SQL Editor mein run karein (schema.sql aur admin.sql ke baad).
2. razorpay.com par account banayein. Pehle TEST mode: Dashboard > Account & Settings > API Keys se test Key ID aur Key Secret lein.
3. Netlify > Site settings > Environment variables mein ye daalein:
   RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET, RAZORPAY_WEBHOOK_SECRET (aap khud ek lamba random text banayein),
   SUPABASE_URL (config.js wala), SUPABASE_SERVICE_ROLE_KEY (Supabase > Settings > API > service_role).
   service_role key SIRF Netlify environment mein rahe. config.js ya GitHub mein kabhi nahi.
4. Razorpay Dashboard > Settings > Webhooks > Add: URL = https://AAPKI-SITE/.netlify/functions/razorpay-webhook,
   Secret = wahi RAZORPAY_WEBHOOK_SECRET, Events = payment.captured aur order.paid.
5. Deploy karein. Customer login karke staff ka "Rs 99 mein unlock karein" dabaye; test mode mein test UPI "success@razorpay"
   ya Razorpay ke test card se payment karke dekhein. Admin > Payments mein entry dikhegi.
7. LIVE jaane ke liye Razorpay KYC/activation poora karein, live keys se Netlify variables badlein, webhook live mode mein bhi banayein.
   Razorpay activation ke liye website par Terms, Privacy aur Refund policy pages (templates diye hain) aur contact details chahiye.

Price Rs 99 server par fixed hai (netlify/functions/create-order.js mein PRICE_PAISE) aur 30 din ka access database function mein.
Payment verify (signature) aur webhook dono se subscription activate hota hai, dobara chalne par double nahi milta.

## Test
TEST_CHECKLIST.md poora flow test karne ke liye hai (test mode mein). supabase/verify.sql security aur paison ka hisaab jaanchta hai (sirf padhta hai).

## Razorpay LIVE
LIVE_CHECKLIST.md follow karein. Admin > Settings > "Go-live check" kai cheezein khud jaanchta hai (netlify/functions/health.js).

## Booking payment aur refund
1. booking_payments.sql ko SQL Editor mein run karein (razorpay.sql ke baad). Naye Netlify env variable ki zarurat nahi.
2. Razorpay Dashboard > Settings > Payment Capture: "Automatic" rakhein (warna payment capture nahi hoti aur refund/settlement atakta hai).
3. Flow: Customer booking form bharta hai -> payment karta hai -> tabhi booking partners ko dikhti hai.
   Payment adhoori rahe to booking "Payment baaki hai" dikhti hai aur Meri Booking mein "Pay" button se dobara pay ho sakta hai.
4. Cancel/refund (server par): partner ke accept karne se pehle = poora refund. Accept ke baad = booking date se kam se kam 1 din pehle tak poora refund;
   uske baad customer cancel nahi kar sakta (admin se hi). Refund original payment method mein 5-7 working din mein jaata hai.
   Refund fail ho to booking "Refund baaki" mein dikhti hai: Admin > Bookings > "Refund baaki" > "Refund bhejein".
5. Partner ko fare mein se platform commission kat kar paisa milta hai (supabase/commission.sql, neeche "Commission" section dekhein).
6. Paisa Razorpay se aapke bank mein settle hota hai; partners ko payout abhi bhi admin panel se aap karte hain. Wallet ka kul balance Admin Overview mein dikhta hai, wo aapki partners ke prati dayitva (liability) hai.
7. GST / income tax ke liye CA se salah lein (platform fee, TDS/TCS ke niyam lag sakte hain).
Owner ke venue jobs (restaurant/hotel) mein abhi payment nahi liya jaata; sirf ghar par booking (customer) mein.

## Commission
1. booking_payments.sql ke baad supabase/commission.sql run karein. Default commission 10% hai.
2. Admin panel > Settings mein % badal sakte hain (0 se 30). Overview mein fee kamai, subscription kamai aur net kamai dikhti hai.
3. Kaise lagta hai: partner ka booking fare (pay) x commission %. Partner jab Accept karta hai tab fee us booking ke liye fix ho jaati hai
   (baad mein % badalne se purani accepted booking par asar nahi). Job list mein partner ko "Booking Rs 1000 - 10% platform fee = aapko Rs 900" dikhta hai.
4. Customer "Kaam ho gaya" confirm kare to partner ke wallet mein (fare - fee) aata hai; wallet history mein fee ka note hota hai.
5. Commission sirf online-paid ghar par bookings par lagta hai. Owner ki venue jobs mein ab wallet credit bhi nahi hota
   (platform ke paas us paise ka koi hissa aata hi nahi). Pehle ye credit ho jaata tha, ye galti thi, theek kar di.
6. Referral discount ka kharch aapka hai, isliye ab uski limit hai: neeche "Discount" section dekhein.
7. Accept ho chuki purani bookings (migration se pehle) par fee 0 rehti hai.
8. Platform fee par GST aur commission income ke tax ke liye CA se salah lein.

## Discount (referral) - kharch par kaabu
1. commission.sql ke baad supabase/discount_fix.sql run karein.
2. Niyam: discount = fare ka 50%, par ek booking par zyada se zyada Max discount (default Rs 150, admin Settings mein badlein).
   Misal: fare Rs 1000 -> discount Rs 150 (500 nahi), customer Rs 850 deta hai. Fare Rs 400 -> discount Rs 150, customer Rs 250 deta hai.
3. Refer karne wale ko reward tab milta hai jab dost ki pehli paid booking POORI ho jaaye (booking banane ya cancel/refund karne se nahi). Pehle ye booking banate hi mil jaata tha: farming ka raasta tha.
4. Booking cancel ho (customer ya admin) to customer ka discount wapas aa jaata hai. Ek customer ke paas max 3 reward credits jama ho sakte hain.
5. Admin Settings mein "Referral discount OFF" ka switch hai (turant band, naye discount nahi milte; jama credits bache rehte hain).
   Admin Overview mein "Discount ka kharch" aur "Baaki discounts (credits)" dikhte hain: yahi aapka customer-acquisition kharch hai.
6. Partner ko ab bhi poora fare (fee ke baad) milta hai; discount aapka (platform ka) kharch hai. Kam kharch chahiye to Max discount ghataayein ya 0 karke band karein.
