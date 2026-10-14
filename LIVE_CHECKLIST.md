# Razorpay LIVE jaane ka checklist

Order se chalein. Har step ke baad tick karein. Admin panel > Settings > "Go-live check" se kai cheezein khud check ho jaati hain.

## A. Pehle (jab tak Razorpay account activate ho raha ho)
- [ ] Razorpay account ka KYC/activation: business ka naam aur type, PAN, bank account, address, website link.
      Razorpay website dekhta hai, isliye Terms, Privacy aur Refund pages live hone chahiye aur unmein [BRACKET] wali details nahi rehni chahiye.
- [ ] terms.html, privacy.html, refund.html mein business ka naam, email, phone, address, date bharein.
      refund.html mein "accepted ke baad cancel" wali line apni policy ke hisaab se likhein. Kisi vakeel/CA se check karwayein.
- [ ] Apni site par kam se kam: kya sell ho raha hai (Rs 99 subscription, ghar par booking), contact details, cancellation/refund rules dikhein.
- [ ] Custom domain lagayein (Netlify > Domain management). HTTPS apne aap aata hai. Razorpay ko wahi domain dein.

## B. Zaroori kanooni/tax sawal (CA/vakeel se pehle poochhein, phir live karein)
- [ ] Is model mein customer ka paisa aapke account mein aata hai aur aap partners ko baad mein bhejte hain. India mein paisa
      isi tarah collect karke baantna payment-aggregator/marketplace ke niyamon ke daayre mein aa sakta hai.
      Razorpay Route (marketplace payments) ya RazorpayX jaisa tareeka laga hai ya nahi, ye Razorpay aur CA se confirm karein.
- [ ] GST registration, platform fee/subscription par GST, partners ko payout par TDS/TCS. Ye sab CA se tay karein.
- [ ] Partners se terms mein sahmati (unka number paid customers ko dikhta hai, payout ke liye bank details lagti hain).

## C. Technical switch (TEST se LIVE)
- [ ] Razorpay Dashboard ko Live mode par karein. Settings > API Keys se LIVE Key ID (rzp_live_...) aur Key Secret banayein.
- [ ] Settings > Payment Capture: "Automatic" (zaroori, warna paisa capture nahi hota).
- [ ] Live mode mein NAYA webhook banayein (test wala live mein kaam nahi karta):
      URL https://AAPKI-SITE/.netlify/functions/razorpay-webhook, events: payment.captured aur order.paid,
      aur ek naya lamba random Secret.
- [ ] Netlify > Environment variables badlein: RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET (live), RAZORPAY_WEBHOOK_SECRET (live wala).
- [ ] Netlify par naya deploy karein (variables badalne ke baad deploy zaroori hai).
- [ ] Supabase > Authentication > Phone: asli SMS provider chalu, test numbers hata dein, rate limit dekh lein.
- [ ] Admin panel > Settings > "Go-live check" dabayein. Sab hare (✅) hone chahiye.

## D. Asli paise se pehla test (apne hi paise, phir refund)
- [ ] Apne number se Customer account: Rs 99 subscription lein. Admin > Payments mein "paid" dikhe, staff ke numbers khul jaayein.
- [ ] Sabse sasti ghar par booking (jaise Rs 100) karke pay karein. Admin > Bookings mein paid dikhe, partner ko dikhe.
- [ ] Doosre number se Partner: Accept karein. Customer "Kaam ho gaya" dabaye. Partner wallet mein (fare - commission) aaye.
- [ ] Ek aur booking pay karke accept se pehle Cancel karein: Razorpay Dashboard > Refunds mein refund dikhna chahiye.
- [ ] Razorpay Dashboard > Payments mein sab entries milti hain, aur Settlements ka schedule dekh lein.
- [ ] Partner ek chhota payout request kare, admin se bank/UPI mein bhejkar "Paid" karein.

## E. Live hone ke baad rozana
- [ ] Admin Overview: "Refund baaki" aur "Payouts pending" khaali karein.
- [ ] Razorpay Dashboard: failed/disputed payments aur webhook failures dekhein.
- [ ] Netlify > Functions logs aur Supabase logs mein errors dekhein.
- [ ] Supabase backups chalu hain ya nahi dekhein (paid plan mein daily backup).
- [ ] Wallet ka kul balance (Admin Overview) aapki partners ke prati zimmedari hai. Itna paisa bank mein hona chahiye.

## F. Kuch galat ho jaaye to
- Galat charge ya double payment: Razorpay Dashboard se refund karein, phir admin Payments/Bookings mein dekhein.
- Payment kat gaya par booking/subscription activate nahi hui: webhook se apne aap hota hai; 10 minute baad bhi na ho to Razorpay mein
  payment ka order id dekhkar admin se manual subscription (Users > +30 din) ya booking check karein.
- Turant rokna ho to Netlify mein RAZORPAY_KEY_SECRET hata dein: naye payments band ho jaayenge, baaki site chalegi.
