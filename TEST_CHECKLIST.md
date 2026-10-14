# StaffWale: poora test checklist

Ye checklist TEST mode (Razorpay test keys) mein chalayein. Har line: **kya karein -> kya dikhna chahiye**.
Fail ho to line ke aage FAIL likhein aur neeche wali "Fail hone par kya bhejein" dekhein. Ek hi baar mein shuru se aakhir tak chalayein, kyunki aage ke tests pichhle tests ke data par chalte hain.

**Kam samay ho to** ye sabse zaroori sections chalayein: 4 (price/discount), 5 (payment), 6 aur 7 (accept aur paisa), 8 (cancel/refund), 13 (suraksha), 15 (hisaab).

## 0. Taiyari

**Zaroori setup (sab ho gaya?)**
- [ ] SQL run ho chuki hai, is order mein: schema.sql, admin.sql, razorpay.sql, booking_payments.sql, commission.sql, discount_fix.sql
- [ ] config.js mein Supabase URL aur anon key; Netlify par site deploy; Razorpay TEST keys aur webhook (payment.captured, order.paid) lage hain
- [ ] Supabase > Authentication > Phone > "Test Phone Numbers and OTPs" mein 6 numbers aur ek fixed OTP daalein (format: `91XXXXXXXXXX=123456`, comma se alag). SMS nahi jaayega.
- [ ] Browser mein 2 alag profile/incognito window rakhein, taaki alag-alag logins ek saath khule rahein.

**6 test accounts**

| Naam | Role | Kaam |
|---|---|---|
| ADMIN | Customer (baad mein admin banega) | admin.html |
| CUST-A | Customer | refer karne wala |
| CUST-B | Customer | CUST-A ke code se aayega |
| PART-1 | Partner (post: Waiter) | booking accept karega |
| PART-2 | Partner (post: Housekeeping) | doosra partner |
| OWNER | Owner | restaurant ki venue job |

**Data check (SQL):** `supabase/verify.sql` ke sections 1 se 7 chalayein.
- [ ] 1: har table par rls = true
- [ ] 2: har function ka exists = true
- [ ] 3: anon_can har row par false. auth_can false: apply_payment, cancel_booking_server, mark_refunded, grant_subscription, owner_cancel, _restore_disc, _fee_pct
- [ ] 4: anon ko koi permission nahi; authenticated ko sirf SELECT, aur UPDATE sirf profiles ke name, city, age, vehicle, post, exp par

## 1. Register aur login (index.html)

- [ ] Bina login ke `app.html` kholo -> `index.html` par bhej deta hai
- [ ] Galat number (9 digit) -> "Sahi 10 digit mobile number daalein"
- [ ] Login tab mein register nahi hua number -> "Ye number registered nahi hai. Register tab chunein."
- [ ] Register: terms par tick na karo -> "Terms se sehmat hona zaroori hai"
- [ ] Galat OTP (123457) -> "OTP galat ya expire ho gaya", sahi OTP (123456) -> app khulta hai
- [ ] Register CUST-A (Customer), PART-1 (Partner, post Waiter), PART-2 (Partner, post Housekeeping), OWNER (Owner), ADMIN (Customer)
- [ ] Register CUST-B: role Customer, referral code mein CUST-A ka code daalo (CUST-A ke app mein Refer a Friend card se copy karo)
- [ ] Logout -> login page; dobara login -> sahi dashboard (Partner ko Profile/Bookings/Wallet..., Customer/Owner ko sirf "Meri Booking")
- [ ] Pehle se registered number se Register karne ki koshish -> login ho jaata hai (naya account nahi banta)
- [ ] Ek aur Customer ko galat referral code se register karo -> account banta hai, par discount nahi milta (aage dekhna)

## 2. Admin setup

- [ ] SQL: `update public.profiles set is_admin = true where mobile = 'ADMIN-KA-10-DIGIT';`
- [ ] ADMIN login karke `/admin.html` -> Overview khulta hai. App ke menu mein "Admin" link bhi dikhta hai.
- [ ] CUST-A se `/admin.html` kholo -> "Aap admin nahi hain"
- [ ] Bina login ke `/admin.html` -> `index.html` par bhej deta hai
- [ ] Settings > "Go-live check": TEST keys, Razorpay keys kaam kar rahi hain

## 3. Partner onboarding aur staff directory

- [ ] PART-1: Profile mein naam, shehar, age, vehicle, post (Waiter), experience bharo, Save -> "Profile save ho gayi"
- [ ] Refresh -> bhari hui details wapas dikhti hain
- [ ] ADMIN > Users > role Partner: dono partners "Pending" dikhte hain; "Sirf pending verification" lagao -> dono aate hain
- [ ] PART-1 par "Verify karein" -> badge "Verified", Overview mein "pending" ghatta hai
- [ ] CUST-A (customer) > Staff section: PART-1 aur PART-2 ke cards dikhte hain, number `99******64` jaisa chhupa hua + 🔒
- [ ] PART-1 ke card par "✔ verified" dikhta hai, PART-2 par nahi
- [ ] Post filter (Waiter / Housekeeping), date chunna, "Sirf free staff" -> sahi cards aate hain
- [ ] "Profile dekhein": Total/Complete/Aane wali, agle 7 din ka hara/laal calendar, bookings ki list (abhi khali), number locked

## 4. Customer booking: price aur discount

Booking form (Ghar par booking) mein CUST-A se (discount nahi, kyunki CUST-A referred nahi hai):

- [ ] Waiter, 4 ghante -> Total ₹400
- [ ] Waiter, 6 ghante -> ₹600 (400 + 2 x 100)
- [ ] Waiter, 4 ghante, Custom "+" 2 baar -> ₹600; "−" se wapas ₹400; ₹0 se neeche nahi jaata
- [ ] Housekeeping, 1 ghanta -> ₹300 (minimum 2 ghante x 150); 3 ghante -> ₹450
- [ ] Chef, budget ₹90 submit -> error "Amount sahi nahi hai" (kam se kam ₹100); ₹500 -> theek
- [ ] Past date nahi chunni ja sakti (date picker ya server error)
- [ ] CUST-A ko discount banner nahi dikhta

CUST-B (CUST-A ke code se aaya):
- [ ] Banner "🎉 Referral offer: 50% off (max ₹150)" dikhta hai
- [ ] Waiter 4 ghante (₹400) -> "aap dein ₹250" (50% = 200, par limit 150, to ₹150 off)
- [ ] Housekeeping 4 ghante (₹600) -> "aap dein ₹450" (limit se ₹150 off)
- [ ] Chef budget ₹200 -> "aap dein ₹100" (50% = ₹100, limit se kam, to poora 50%)
- [ ] Galat referral code wale customer ko banner nahi dikhta

## 5. Payment (Razorpay TEST)

Test UPI: `success@razorpay` (safal), `failure@razorpay` (fail). Test card: 4111 1111 1111 1111, koi bhi aage ki expiry, koi CVV (Razorpay docs dekh lein agar badal gaya ho).

- [ ] CUST-A: Waiter booking (kal ki date) -> "Booking karein aur pay karein" -> Razorpay khulta hai, amount sahi (₹400)
- [ ] Payment fail karo (`failure@razorpay`) -> toast mein error; booking "Payment baaki" dikhti hai Meri Booking mein
- [ ] Is booking par PART-1 ke Live jobs mein **nahi** dikhti (payment ke bina partner ko nahi dikhni chahiye)
- [ ] Meri Booking > "Abhi pay karein" -> `success@razorpay` se pay -> "Payment mil gaya", status "Partner dhundh rahe hain"
- [ ] Ab PART-1 ko Live jobs mein ye booking dikhti hai (venue "Ghar par", sirf shehar, address nahi)
- [ ] Admin > Bookings: pay_status paid; Admin > Payments: entry "paid"
- [ ] CUST-B ki discounted booking pay karo: Razorpay mein discounted amount (₹250) dikhe, ₹400 nahi
- [ ] **Browser band wala test:** nayi booking, Razorpay mein payment poora karte hi tab band kar do. 1-2 minute baad dekho: booking apne aap paid ho gayi (webhook se). Na ho to Razorpay Dashboard > Webhooks mein delivery check karo.
- [ ] Bina payment wali booking ko Cancel karo -> "Booking cancel ho gayi", refund nahi (kuch dena hi nahi tha)

## 6. Partner accept aur commission

- [ ] PART-1 ke Live jobs mein: "₹X | Booking ₹400 − 10% platform fee = aapko ₹360"
- [ ] PART-1 "Accept karein" -> Bookings tab mein "Accepted", customer ka naam, mobile aur poora address dikhta hai
- [ ] CUST-A ki Meri Booking mein status "Accepted", partner ka naam dikhta hai (partner ka number nahi)
- [ ] Wahi booking PART-2 ko ab Live jobs mein nahi dikhti
- [ ] Do bookings ek hi date aur slot par PART-1 accept kare -> doosri par "Is date aur slot par aapki booking pehle se hai"
- [ ] PART-1 "Cancel" -> booking wapas Open hoti hai aur dobara Live jobs mein dikhti hai
- [ ] Admin Settings mein commission 10 se 20 karo. Pehle se accepted booking par fee 10% hi rehti hai (naye accept par 20% dikhega)

## 7. Kaam poora hone par

- [ ] CUST-A "Kaam ho gaya" -> confirm box -> "Booking complete ho gayi"
- [ ] PART-1 ka Wallet: ₹400 booking par ₹360 aaya, history mein "Booking: Waiter (date) - 10% platform fee"
- [ ] PART-1 > Earnings: tiles aur is mahine ka bar chart update
- [ ] Wahi booking dobara confirm nahi hoti (button gayab / error)
- [ ] Referral reward: CUST-B ki booking poori hone se **pehle** CUST-A ka reward nahi aana chahiye. CUST-B ki pehli paid booking par partner accept kare aur CUST-B "Kaam ho gaya" dabaye -> ab CUST-A ko reward credit mile (CUST-A ki agli booking par banner: "🎁 Refer reward")
- [ ] CUST-B ki doosri booking par discount nahi (pehla wala istemal ho gaya)
- [ ] Reward sirf ek baar: CUST-B ki teesri booking poori ho to CUST-A ko dobara reward nahi
- [ ] **Owner venue job:** OWNER "Job post karein" (Waiter, ₹800) -> Live jobs mein dikhti hai (payment ke bina). PART-1 accept, OWNER Meri Booking se "Kaam ho gaya" dabaye -> PART-1 ke wallet mein **kuch nahi** aana chahiye (platform ko paisa mila hi nahi)

## 8. Cancel aur refund

- [ ] Nayi paid booking (kal ki date), partner ke accept se **pehle** CUST-A Cancel -> toast "Refund 5-7 din mein aayega"; Razorpay Dashboard > Refunds mein refund dikhta hai; admin Bookings mein "refunded"
- [ ] Cancel karne ke baad CUST-B ka discount wapas (banner dubara dikhta hai)
- [ ] Paid booking, partner accept kare (booking kal ya baad ki), customer Cancel -> poora refund
- [ ] Aaj ki date ki booking, accept hone ke baad customer Cancel -> "Booking ke din ya uske baad cancel nahi ho sakti. Support se sampark karein"
- [ ] ADMIN > Bookings: wahi booking Cancel karo -> pay_status "Refund baaki" ban jaata hai
- [ ] ADMIN > Bookings > "Refund baaki" filter > "Refund bhejein" -> Razorpay mein refund; status "refunded"
- [ ] Refund fail wala raasta (optional): Netlify mein RAZORPAY_KEY_SECRET galat karke cancel karo -> booking "Refund baaki" dikhti hai (customer ko "Refund process mein hai"), baad mein secret theek karke admin se refund bhejo
- [ ] Payment aate-aate booking cancel: payment poora hone se pehle doosre tab se booking cancel karo, phir payment poora karo -> booking cancelled rehti hai aur "Refund baaki" ban jaata hai

## 9. ₹99 subscription aur staff numbers

- [ ] CUST-A (subscription nahi): staff card par number locked; profile mein "₹99 mein unlock karein"
- [ ] Unlock dabao -> Razorpay ₹99 -> `success@razorpay` -> "Subscription active", upar bar mein expiry date, saare numbers khul gaye, Call/WhatsApp buttons aaye
- [ ] Admin > Payments mein ₹99 subscription "paid"
- [ ] Naya tab/refresh karne ke baad bhi numbers khule rehte hain
- [ ] Expiry test (SQL): `update profiles set sub_until = current_date - 1 where mobile = 'CUST-A';` -> refresh -> numbers phir locked
- [ ] PART-1 login: subscription ka button kaam nahi karta ("sirf Customer ya Owner ke liye")
- [ ] ADMIN > Users > CUST-A > "+30 din sub" -> numbers khul jaate hain, Admin Settings log mein entry
- [ ] Payment dobara (double click / dobara webhook) karne par subscription 30 din hi badhta hai, 60 nahi

## 10. Wallet aur payout

PART-1 ke wallet mein paisa hona chahiye (section 7 ke baad).
- [ ] Bank Details: galat IFSC -> error "IFSC sahi nahi hai"; 8 digit account -> error; sahi details -> "Bank details save ho gayi"
- [ ] Withdraw ₹50 -> "Minimum withdraw 100 rupaye hai"; balance se zyada -> "Wallet mein sirf ... rupaye hain"
- [ ] Bank details ke bina Withdraw (naya partner) -> "Pehle Bank Details save karein"
- [ ] Withdraw ₹100 -> wallet ghatta hai, Payouts tab mein "Processing", wallet history mein "Withdrawn"
- [ ] ADMIN > Payouts: request dikhti hai, bank/UPI details ke saath. "Paid" -> partner ko status "Paid"
- [ ] Ek aur withdraw -> admin "Reject" -> paisa wallet mein wapas, history mein "Payout reject hui"
- [ ] Wahi payout dobara Paid/Reject karne par "pehle hi process ho chuka hai"

## 11. Reviews, share aur links

- [ ] Review do (⭐⭐⭐⭐⭐) -> average aur list update. Bina login ke review -> login maangta hai
- [ ] ADMIN > Reviews: delete -> list se gayab
- [ ] Refer card: "WhatsApp par bhejein" khulta hai message aur code ke saath; "Code copy karein" kaam karta hai
- [ ] Instagram, Facebook, WhatsApp buttons aur floating WhatsApp button **aapke asli links** par jaate hain (config.js mein placeholder to nahi?)
- [ ] Terms, Privacy, Refund pages khulte hain aur unmein [BRACKET] details nahi bachi

## 12. Admin panel poora

- [ ] Overview: users, bookings ki ginti, fee kamai, subscription kamai, "Discount ka kharch", "Baaki discounts"
- [ ] Users: naam/mobile search, role filter, Verify/Unverify
- [ ] Bookings: status filter, "Refund baaki" filter
- [ ] Payments: "Paid", "Refund pending" cards aur table
- [ ] Settings: commission save, Max discount save (jaise 100 -> CUST-B ki agli booking par limit ₹100), "Referral discount OFF" -> discount band, ON -> wapas
- [ ] Settings ke neeche Admin actions log mein har badlaav ki entry
- [ ] Commission 31 daalo -> error (0 se 30 hi)

## 13. Suraksha ke test (browser console se)

CUST-A ke app.html mein login rehte hue Console (F12) mein poora block ek saath paste karein (pehli baar). Dobara chalana ho to pehle page refresh karein (warna "already declared" error aata hai). Har line ka natija `console.log` se numbering ke saath dikhega, aur line ke aage likha hai ki kya aana chahiye.

```js
const t = supabase.createClient(SW_CONFIG.SUPABASE_URL, SW_CONFIG.SUPABASE_ANON_KEY);
const me = (await t.auth.getUser()).data.user.id;
const P = {p_kind:'home',p_role:'Waiter',p_venue:null,p_city:'Jaipur',p_address:'test',p_date:'2099-01-01',p_slot:'Shaam',p_hours:4,p_guests:4,p_notes:null,p_budget:null,p_extra:0};

console.log(1, (await t.from('profiles').update({wallet:99999, role:'Owner', is_admin:true}).eq('id', me)).error);   // error aana chahiye (permission denied)
console.log(2, (await t.from('profiles').select('mobile')).data.length);                                              // 1 (sirf apni)
console.log(3, (await t.from('wallet_tx').insert({user_id:me,type:'Payments',note:'x',amount:5000})).error);          // error
console.log(4, (await t.from('jobs').insert({owner_id:me,kind:'home',role:'Waiter',city:'x',job_date:'2099-01-01',pay:1,customer_pays:1})).error);  // error
console.log(5, (await t.from('bank_details').select('*')).data);                                                      // [] (kisi ki nahi)
console.log(6, (await t.rpc('admin_stats')).error);                                                                   // "Sirf admin ke liye"
console.log(7, (await t.rpc('apply_payment',{p_order:'x',p_payment:'y'})).error);                                     // permission denied
console.log(8, (await t.rpc('cancel_booking_server',{p_job:'00000000-0000-0000-0000-000000000000',p_uid:me})).error); // permission denied
console.log(9, (await t.rpc('accept_job',{p_id:'00000000-0000-0000-0000-000000000000'})).error);                      // "Sirf Partner accept kar sakte hain"
console.log(10, (await t.rpc('create_job',{...P,p_extra:5000})).error);                                                // "Custom amount sahi nahi hai"
console.log(11, (await t.rpc('create_job',{...P,p_role:'Chef',p_budget:50})).error);                                   // "Amount sahi nahi hai"
console.log(12, (await t.rpc('create_job',{...P,p_date:'2020-01-01'})).error);                                         // "Date sahi nahi hai"
const pid = (await t.from('staff_public').select('id')).data[0].id;
console.log(13, (await t.rpc('staff_phone',{pid})).data);                                                              // null (subscription ke bina)
const a = supabase.createClient(SW_CONFIG.SUPABASE_URL, SW_CONFIG.SUPABASE_ANON_KEY, {auth:{persistSession:false,storageKey:'anon-test'}});
console.log(14, (await a.from('staff_public').select('*')).error);                                                     // error (bina login ke nahi)
console.log(15, (await a.rpc('public_config')).error);                                                                 // error
```
- [ ] Upar ki har line ka result sahi aaya (kuch bhi "chal gaya" to sabse badi samasya hai: turant mujhe bhejein)
- [ ] PART-1 ke login se: `create_job` -> "Partner booking nahi kar sakte"
- [ ] CUST-A se kisi doosre user ki booking ka id lekar `confirm_complete` / `partner_cancel` chalane par error

**Netlify functions (terminal se, SITE = aapki site):**
```
curl -i -X POST https://SITE/.netlify/functions/create-order                       # 401 (login ke bina)
curl -i -X POST https://SITE/.netlify/functions/verify-payment -d '{"razorpay_order_id":"a","razorpay_payment_id":"b","razorpay_signature":"c"}'   # 400
curl -i -X POST https://SITE/.netlify/functions/razorpay-webhook -d '{}'            # 400 (signature ke bina)
curl -i -X POST https://SITE/.netlify/functions/health                              # 401
```
- [ ] Chaaron ke jawab upar likhe jaise aaye

## 14. Mobile aur dikhawat

- [ ] Phone par poora flow (login, booking, pay, dashboard): kuch kata/ghuma nahi
- [ ] Dark mode: text padhne layak hai
- [ ] Tab/menu, dialog (staff profile, subscription) band hote hain, keyboard se bhi (Tab key, Esc)
- [ ] Slow internet par Razorpay load na ho to saaf error aata hai ("Razorpay load nahi hua")

## 15. Test ke baad paison ka hisaab (supabase/verify.sql, sections 8 se 13)

- [ ] 8: har partner ka `difference` = 0
- [ ] 9: razorpay_booking_total = jobs_total
- [ ] 10: har booking ka status aur pay_status aapke test ke hisaab se (cancelled+paid to `refunded` ya `refund_due`)
- [ ] 11: partner_wallets_total aur payouts_pending aapke haath ke hisaab se milte hain
- [ ] 12: koi row nahi aani chahiye
- [ ] 13: admin ke har action ka record hai
- [ ] Admin Overview: "Net platform kamai" = fee + subscription - discount ka kharch, hisaab laga kar dekh lo

## 16. Live jaane se pehle aakhri

- [ ] Test numbers Supabase se hata do (warna fixed OTP se koi bhi login kar sakta hai)
- [ ] Test data saaf karo ya naya project lo (SQL: test users/bookings delete)
- [ ] LIVE_CHECKLIST.md poora karo, Go-live check sab ✅

## Fail hone par kya bhejein
1. Kaun sa section/line number aur kya hua (screenshot).
2. Browser Console (F12) ke laal errors.
3. Netlify > Functions > us function ka log, aur Supabase > Logs.
4. Agar paison ka hisaab nahi mila: verify.sql ke sections 8-10 ka output.
