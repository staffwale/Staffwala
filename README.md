# StaffWale – Netlify package

## Files
- index.html  → Login / Register page (pehla page, OTP ke baad app.html khulta hai)
- app.html    → Poori website (booking, staff, wallet, dashboard, reviews)
- config.js   → DEMO_MODE on/off
- netlify/functions/send-otp.js, verify-otp.js → asli SMS OTP (MSG91)
- netlify.toml

## 1) Abhi publish (Demo OTP 123456)
Is poore folder ko https://app.netlify.com/drop par drag & drop karein. Site live ho jaati hai.

## 2) Asli SMS OTP
1. MSG91 account banayein, OTP template banwayein (India mein DLT registration zaroori hai).
2. Site ko GitHub se ya `netlify deploy --prod` (Netlify CLI) se deploy karein, taaki functions chalein.
3. Netlify > Site settings > Environment variables:
   MSG91_AUTHKEY, MSG91_TEMPLATE_ID, OTP_SECRET (lamba random text)
4. config.js mein DEMO_MODE ko false karein, dobara deploy karein.

## 3) Apne links badlein
app.html mein `SOC={ig:..., fb:..., wa:'919999999999'}` dhundhkar asli Instagram, Facebook aur WhatsApp number daalein.

## Zaroori limits
- OTP verification asli ho jaati hai, lekin accounts, bookings, wallet aur subscription abhi browser (localStorage) mein save hote hain.
  Isliye ek phone par bana account doosre phone par login nahi hoga.
  Asli use ke liye database chahiye (jaise Supabase ya Firebase).
- Payments (wallet, Rs 99 subscription) demo hain. Asli ke liye Razorpay/Cashfree jaisa gateway chahiye.
- OTP function par rate-limit nahi hai. Live karne se pehle add karein.
