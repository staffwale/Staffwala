(function(){
'use strict';
var CFG=window.SW_CONFIG||{};
var $=function(i){return document.getElementById(i)};
if(!CFG.SUPABASE_URL||/YOUR-/.test(CFG.SUPABASE_URL)){document.body.insertAdjacentHTML('afterbegin','<p style="padding:20px;font-weight:600">config.js mein Supabase URL aur anon key daalein (README dekhein).</p>');return}
var sb=supabase.createClient(CFG.SUPABASE_URL,CFG.SUPABASE_ANON_KEY);
var ROLES=[{n:'Waiter',e:'🍽️',c:'#fde9b0',d:'Table service'},{n:'Bartender',e:'🍸',c:'#f6c9d0',d:'Cocktails & bar'},{n:'Barista',e:'☕',c:'#e7d3bd',d:'Coffee & café'},{n:'Chef',e:'👨‍🍳',c:'#d6ecd9',d:'Kitchen & cooking'},{n:'Housekeeping',e:'🧹',c:'#cfe6f5',d:'Rooms & cleaning'},{n:'GRE',e:'🛎️',c:'#e5dcf5',d:'Guest relations'},{n:'Helper',e:'🧺',c:'#ffe0c2',d:'Kitchen / floor helper'},{n:'Security',e:'💂',c:'#d9dde3',d:'Guard & gate'}];
var DN=['Sun','Mon','Tue','Wed','Thu','Fri','Sat'],TF=['All','Payments','Added','Withdrawn'];
var PC={max_discount:150,referral_on:true};
var ME=null,JOBS=[],STAFF=[],BUSY=[],TX=[],PJ=[],XT=0,flt='All',txf='All',curSt=null;

function esc(s){return String(s==null?'':s).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]})}
function info(n){return ROLES.filter(function(r){return r.n===n})[0]||ROLES[0]}
function dstr(o){var d=new Date();d.setDate(d.getDate()+(o||0));return new Date(d-d.getTimezoneOffset()*6e4).toISOString().slice(0,10)}
function today(){return dstr(0)}
function opts(sel){return ROLES.map(function(r){return '<option'+(r.n===sel?' selected':'')+'>'+r.n+'</option>'}).join('')}
function toast(m){var t=$('toast');t.textContent=m;t.classList.add('on');clearTimeout(toast.t);toast.t=setTimeout(function(){t.classList.remove('on')},3200)}
function say(id,m){$(id).textContent=m||''}
async function rpc(n,a){var r=await sb.rpc(n,a||{});if(r.error)throw new Error(r.error.message);return r.data}
async function api(n,b,tok){var r=await fetch('/.netlify/functions/'+n,{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+tok},body:JSON.stringify(b||{})});var d={};try{d=await r.json()}catch(e){}if(!r.ok)throw new Error(d.error||'Server error');return d}
function rzPay(o,tok,desc){return new Promise(function(res,rej){
  if(typeof Razorpay==='undefined')return rej(new Error('Razorpay load nahi hua. Internet check karein.'));
  var z=new Razorpay({key:o.key_id,order_id:o.order_id,amount:o.amount,currency:'INR',name:'StaffWale',description:desc,prefill:{contact:ME.mobile,name:ME.name},theme:{color:'#f2c200'},
    handler:function(r){api('verify-payment',r,tok).then(res,rej)},modal:{ondismiss:function(){rej(new Error('Payment cancel ho gaya.'))}}});
  z.on('payment.failed',function(x){rej(new Error('Payment fail hui: '+((x.error&&x.error.description)||'')))});z.open()})}
async function payJob(id){
  var tok=(await sb.auth.getSession()).data.session.access_token,o=await api('create-booking-order',{job_id:id},tok);
  await rzPay(o,tok,'Booking payment');toast('Payment mil gaya. Ab partner dhundhna shuru.')}
async function tab(fn){try{return await fn()}catch(e){toast(e.message||'Kuch gadbad hui. Dobara try karein.');return null}}
function subOn(){return !!(ME&&ME.sub_until&&ME.sub_until>=today())}
function discOn(){return !!(ME&&ME.role==='Customer'&&PC.referral_on&&(ME.disc_available||ME.reward_credits>0))}
function isPartner(){return ME&&ME.role==='Partner'}

async function loadMe(){var u=(await sb.auth.getUser()).data.user;if(!u)return false;var r=await sb.from('profiles').select('*').eq('id',u.id).single();ME=r.data;return !!ME}

/* ---------- Jobs board ---------- */
async function loadJobs(){var r=await sb.from('jobs_open').select('*').order('created_at',{ascending:false});JOBS=r.data||[];rRoles();rChips();rJobs()}
function rRoles(){$('roleGrid').innerHTML=ROLES.map(function(r){var n=JOBS.filter(function(j){return j.role===r.n}).length;return '<button class="role" data-r="'+r.n+'"><div class="ic" style="background:'+r.c+'">'+r.e+'</div><b>'+r.n+'</b><small>'+r.d+' · '+n+' jobs</small></button>'}).join('')}
function rChips(){$('chips').innerHTML=['All'].concat(ROLES.map(function(r){return r.n})).map(function(n){return '<button class="chip" data-f="'+n+'" aria-pressed="'+(n===flt)+'">'+n+'</button>'}).join('')}
function rJobs(){
  var s=$('jq').value.toLowerCase(),l=JOBS.filter(function(j){return (flt==='All'||j.role===flt)&&(j.role+' '+j.venue+' '+j.city).toLowerCase().indexOf(s)>-1});
  if($('jsort').value==='pay')l=l.slice().sort(function(a,b){return b.pay-a.pay});
  $('jobList').innerHTML=l.length?l.map(function(j){var r=info(j.role);
    var btn=isPartner()?'<button class="btn" data-acc="'+j.id+'">Accept karein</button>':'<span class="meta">Accept sirf Partner kar sakte hain</span>';
    return '<article class="job"><div class="top"><div class="em" style="background:'+r.c+'">'+r.e+'</div><div><h3>'+j.role+'</h3><div class="meta">'+esc(j.venue)+', '+esc(j.city)+'</div></div></div>'+(isPartner()&&j.fee_pct>0?'<div class="pay">₹'+j.net+(j.hours?' total':' / shift')+'</div><div class="meta">Booking ₹'+j.pay+' − '+j.fee_pct+'% platform fee = aapko ₹'+j.net:'<div class="pay">₹'+j.pay+(j.hours?' total':' / shift'))+'</div><div class="meta">Date: '+j.job_date+(j.slot?' · '+esc(j.slot):'')+(j.guests?' · '+j.guests+' log':'')+(j.hours?' · '+j.hours+' hrs':'')+'</div>'+(j.kind==='home'?'<div class="meta">🏠 Ghar par booking</div>':'')+btn+'</article>'}).join(''):'<div class="empty">Abhi koi live job nahi hai.</div>'}

/* ---------- Home booking form + price ---------- */
function hrsRole(){var r=$('hRole').value;return r==='Waiter'||r==='Housekeeping'}
function hCalc(){
  var r=$('hRole').value,h=+$('hHrs').value||4,hr=hrsRole(),base=0,txt='';
  $('hHrsW').classList.toggle('hid',!hr);$('hCalc').classList.toggle('hid',!hr);$('hBudW').classList.toggle('hid',hr);
  if(r==='Waiter'){base=400+Math.max(0,h-4)*100;txt='Base ₹400 (pehle 4 ghante)'+(h>4?' + ₹'+(h-4)*100+' extra ghante':'')}
  else if(r==='Housekeeping'){var hh=Math.max(2,h);base=hh*150;txt=hh+' ghante × ₹150 (minimum 2 ghante)'}
  var fare=hr?base+XT:(+$('hBudget').value||0),off=discOn(),d=off?Math.min(Math.round(fare/2),PC.max_discount):0;
  $('hBreak').textContent=txt+(XT?' + Custom ₹'+XT:'');$('xTxt').textContent='Custom +₹'+XT;
  $('hDisc').classList.toggle('hid',!off);if(off)$('hDisc').textContent=(ME.disc_available?'🎉 Referral offer: ':'🎁 Refer reward: ')+'50% off (max ₹'+PC.max_discount+')'+(d?' - is booking par ₹'+d+' ki bachat':'');
  $('hTotal').innerHTML=fare?'Total ₹'+fare+(off&&d?' → aap dein <b>₹'+(fare-d)+'</b>':''):'';
  return fare;
}

/* ---------- Orders (customer / owner) ---------- */
async function rO(){
  if(isPartner())return;
  var l=await rpc('my_orders');
  $('coList').innerHTML=l.length?l.map(function(c){
    var price=c.disc?'<s>₹'+c.fare+'</s> ₹'+c.pays+' (₹'+(c.fare-c.pays)+' off)':'₹'+c.fare;
    var unpaid=c.kind==='home'&&c.pay_status==='unpaid'&&c.status==='Open';var st=(unpaid?'Payment baaki hai':(c.status==='Open'?'Partner dhundh rahe hain':c.status))+(c.pay_status==='refund_due'?' · Refund process mein':(c.pay_status==='refunded'?' · Refund ho gaya':''));
    var acts=(unpaid?'<button class="btn" data-pay="'+c.id+'" style="padding:6px 10px;font-size:14px">Pay ₹'+c.pays+'</button>':'')+(c.status==='Accepted'?'<button class="btn" data-cf="'+c.id+'" style="padding:6px 10px;font-size:14px">Kaam ho gaya</button>':'')+((c.status==='Open'||c.status==='Accepted')?'<button class="btn alt" data-co="'+c.id+'" style="padding:6px 10px;font-size:14px">Cancel</button>':'');
    return '<div class="tx" style="align-items:center"><div><b>'+c.role+'</b> · '+c.date+(c.slot?' · '+esc(c.slot):'')+'<br><span class="meta">'+(c.kind==='home'?esc(c.address||'')+' · ':esc(c.venue||'')+' · ')+(c.guests?c.guests+' log · ':'')+(c.hours?c.hours+' hrs · ':'')+price+(c.pname?'<br>Partner: '+esc(c.pname):'')+'</span></div><span style="display:flex;flex-direction:column;gap:6px;align-items:flex-end"><span class="badge'+(c.status==='Accepted'||c.status==='Completed'?' ok2':'')+'">'+st+'</span>'+acts+'</span></div>'}).join(''):'<div class="empty">Abhi koi booking nahi. Upar "Ghar par booking" form bharein.</div>';
}

/* ---------- Partner bookings / wallet / earnings ---------- */
async function rB(){
  if(!isPartner())return;
  PJ=await rpc('my_partner_jobs');
  $('bkList').innerHTML=PJ.length?PJ.map(function(x){
    var home=x.kind==='home';
    var det=(x.status==='Accepted'||x.status==='Completed')?'<br><span class="meta">'+(home?'🏠 '+esc(x.address||'')+' · ':'')+esc(x.cname)+' · '+esc(x.cmobile)+'</span>':'';
    return '<div class="tx" style="align-items:center"><div><b>'+x.role+'</b> · '+esc(home?'Ghar par':x.venue)+'<br><span class="meta">'+esc(x.city)+' · '+x.date+(x.slot?' · '+esc(x.slot):'')+' · ₹'+(x.pay_status==='paid'&&x.fee_pct>0?(x.pay-x.fee_amt)+' (fee '+x.fee_pct+'% ke baad)':x.pay)+' · '+x.status+'</span>'+det+'</div>'+(x.status==='Accepted'?'<button class="btn alt" data-pc="'+x.id+'" style="padding:6px 10px;font-size:14px">Cancel</button>':'')+'</div>'}).join(''):'<div class="empty">Koi booking nahi. Live jobs mein Accept karein.</div>';
}
async function rW(){
  if(!isPartner())return;
  var t=await sb.from('wallet_tx').select('*').order('created_at',{ascending:false}).limit(100);TX=t.data||[];
  $('wBal').textContent='₹'+ME.wallet;
  $('wTf').innerHTML=TF.map(function(n){return '<button class="chip2" data-t="'+n+'" aria-pressed="'+(n===txf)+'">'+n+'</button>'}).join('');
  var l=TX.filter(function(x){return txf==='All'||x.type===txf});
  $('wTx').innerHTML=l.length?l.map(function(x){return '<div class="tx"><div><b>'+x.type+'</b><br><span class="meta">'+esc(x.note)+' · '+String(x.created_at).slice(0,10)+'</span></div><b class="'+(x.amount<0?'neg':'pos')+'">'+(x.amount<0?'-':'+')+'₹'+Math.abs(x.amount)+'</b></div>'}).join(''):'<div class="empty">no records</div>';
  var p=await sb.from('payouts').select('*').order('created_at',{ascending:false});
  $('oList').innerHTML=(p.data&&p.data.length)?p.data.map(function(o){return '<div class="tx"><div><b>₹'+o.amount+'</b><br><span class="meta">'+esc(o.dest)+' · '+String(o.created_at).slice(0,10)+'</span></div><span class="badge'+(o.status==='Paid'?' ok2':'')+'">'+o.status+'</span></div>'}).join(''):'<div class="empty">Abhi koi payout nahi.</div>';
  var b=await sb.from('bank_details').select('holder,ifsc,upi').maybeSingle();
  if(b.data){$('bName').value=b.data.holder||'';$('bIfsc').value=b.data.ifsc||'';$('bUpi').value=b.data.upi||''}
  rE();
}
function rE(){
  var M=['Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct'],tot={},cnt={},c=0,a=0,e=0;
  PJ.forEach(function(j){if(j.status==='Accepted')a++});
  TX.forEach(function(x){if(x.type==='Payments'){var m=+String(x.created_at).slice(5,7);tot[m]=(tot[m]||0)+x.amount;cnt[m]=(cnt[m]||0)+1;c++;e+=x.amount}});
  function bars(d,f){var mx=1;M.forEach(function(m,i){mx=Math.max(mx,d[i+2]||0)});return M.map(function(m,i){var v=d[i+2]||0;return '<div class="bar"><em style="font-style:normal">'+f(v)+'</em><i style="height:'+(v?Math.max(8,Math.round(v/mx*100)):2)+'px"></i><span>'+m+'</span></div>'}).join('')}
  $('eBars').innerHTML=bars(tot,function(v){return '₹'+(v/1000).toFixed(1).replace('.0','')+'K'});$('bBars').innerHTML=bars(cnt,function(v){return v});
  $('t1').textContent=c;$('t2').textContent=a;$('t3').textContent=e;$('t4').textContent=ME.wallet;
}

/* ---------- Staff directory ---------- */
async function loadStaff(){var r=await sb.from('staff_public').select('*');STAFF=r.data||[];BUSY=await rpc('busy_dates',{p_date:$('sDate').value||today()});rS()}
function rSub(){$('subBar').innerHTML=subOn()?'<span>✅ Subscription active · <b>'+ME.sub_until+'</b> tak · saare staff ke numbers unlock hain.</span>':'<span>🔒 Staff ke numbers hidden hain. <b>₹99 / 30 din</b> ka subscription lekar unlock karein.</span><button class="btn" type="button" data-sub>₹99 mein unlock karein</button>'}
function rS(){
  var role=$('sRole').value,fr=$('sFree').checked,d=$('sDate').value||today();
  var l=STAFF.filter(function(s){return (role==='All'||s.post===role)&&(!fr||BUSY.indexOf(s.id)<0)});
  $('stList').innerHTML=l.length?l.map(function(s){var b=BUSY.indexOf(s.id)>=0,ri=info(s.post);
    return '<article class="job"><div class="top"><div class="em" style="background:'+ri.c+'">'+ri.e+'</div><div><h3>'+esc(s.name)+(s.verified?' <small class="meta">✔ verified</small>':'')+'</h3><div class="meta">'+esc(s.post||'Partner')+' · '+esc(s.city||'')+'</div></div></div><div class="meta">'+s.done+' complete · '+s.upcoming+' aane wali · '+(s.exp?s.exp+' saal':'Naya partner')+'</div><div><span class="badge'+(b?'':' ok2')+'">'+(b?'Booked':'Free')+' · '+d+'</span></div><div class="meta">📞 '+(subOn()?'Profile mein dekhein':esc(s.mask)+' 🔒')+'</div><button class="btn" data-st="'+s.id+'" type="button">Profile dekhein</button></article>'}).join(''):'<div class="empty">Abhi is filter mein koi staff nahi hai.</div>';
}
async function rST(id){
  curSt=id;var s=STAFF.filter(function(x){return x.id===id})[0];if(!s)return;
  var bk=await rpc('staff_bookings',{pid:id}),ph=subOn()?await rpc('staff_phone',{pid:id}):null,ri=info(s.post);
  var up=bk.filter(function(x){return x.status==='Accepted'}).sort(function(a,b){return a.date<b.date?-1:1}),dn=bk.filter(function(x){return x.status==='Completed'});
  function row(x){return '<div class="tx"><div><b>'+x.date+'</b> <span class="badge'+(x.status==='Completed'?' ok2':'')+'">'+x.status+'</span><br><span class="meta">By '+esc(x.by)+' · '+esc(x.kind==='home'?x.role+' (ghar par)':x.role+' at '+(x.venue||''))+(x.slot?' · '+esc(x.slot):'')+(x.hours?' · '+x.hours+' hrs':'')+(x.guests?' · '+x.guests+' log':'')+'</span></div></div>'}
  var days='';for(var i=0;i<7;i++){var d=dstr(i),bz=bk.some(function(x){return x.date===d});days+='<div class="dy '+(bz?'busy':'free')+'"><b>'+DN[new Date(d+'T00:00:00Z').getUTCDay()]+'</b>'+d.slice(8)+'/'+d.slice(5,7)+'<br>'+(bz?'Booked':'Free')+'</div>'}
  var ct=ph?'<div class="disc">📞 '+esc(ph)+'</div><div class="share" style="margin-top:8px"><a class="sh" href="tel:'+esc(ph)+'">Call</a><a class="sh wa" target="_blank" rel="noopener" href="https://wa.me/91'+esc(ph)+'">WhatsApp</a></div>':'<div class="lockbox"><div>🔒 <b>'+esc(s.mask)+'</b><br><span class="meta">Number dekhne ke liye ₹99 subscription chahiye.</span></div><button class="btn" data-sub type="button">₹99 mein unlock karein</button></div>';
  $('stBody').innerHTML='<div style="display:flex;gap:12px;align-items:center;margin:10px 0"><div class="em" style="width:56px;height:56px;border-radius:14px;display:grid;place-items:center;font-size:30px;background:'+ri.c+'">'+ri.e+'</div><div><h3 style="font-size:21px">'+esc(s.name)+'</h3><div class="meta">'+esc(s.post||'Partner')+' · '+esc(s.city||'')+' · '+(s.exp?s.exp+' saal experience':'Naya partner')+'</div></div></div>'
   +'<div class="tiles" style="grid-template-columns:repeat(3,1fr)"><div class="tile"><b>'+bk.length+'</b>Total</div><div class="tile"><b>'+dn.length+'</b>Complete</div><div class="tile"><b>'+up.length+'</b>Aane wali</div></div>'
   +ct+'<h3 style="font-size:17px;margin-top:6px">Agle 7 din</h3><div class="days">'+days+'</div>'
   +'<h3 style="font-size:17px">Aane wali bookings</h3>'+(up.length?up.map(row).join(''):'<div class="empty">Koi upcoming booking nahi, staff free hai.</div>')
   +'<h3 style="font-size:17px;margin-top:14px">Purani bookings</h3>'+(dn.length?dn.map(row).join(''):'<div class="empty">Abhi koi complete booking nahi.</div>')
   +'<p class="note" style="margin-top:10px">Customer ke naam chhupe hue hain; unke number kabhi nahi dikhte.</p>';
  if(!$('stDlg').open)$('stDlg').showModal();
}
function openSub(){if(!ME||(ME.role!=='Customer'&&ME.role!=='Owner')){toast('Subscription sirf Customer ya Owner ke liye hai.');return}$('subDlg').showModal()}

/* ---------- Reviews / referral ---------- */
async function rR(){
  var r=await sb.from('reviews').select('*').order('created_at',{ascending:false}).limit(50),l=r.data||[];
  $('revAvg').textContent=l.length?'★ '+(l.reduce(function(s,x){return s+x.stars},0)/l.length).toFixed(1)+' / 5 · '+l.length+' reviews':'Abhi koi review nahi. Pehla review aap dein.';
  $('revList').innerHTML=l.length?l.map(function(x){return '<div class="tx"><div><b>'+esc(x.name)+'</b> <span style="color:#b38f00">'+'★'.repeat(x.stars)+'</span><br><span class="meta">'+esc(x.body)+'</span></div><span class="meta">'+String(x.created_at).slice(0,10)+'</span></div>'}).join(''):'<div class="empty">no reviews yet</div>';
}
function setLink(id,href){var el=$(id);if(!el)return;if(href){el.href=href;el.style.display=''}else el.style.display='none'}
function rRef(){
  var c=ME.ref_code,t='StaffWale se ghar par cook, waiter ya housekeeping book karein. Mera code '+c+' use karein aur pehli booking par 50% off (max ₹'+PC.max_discount+') paayein! '+location.origin;
  $('refCode').textContent=c;$('shWa').href='https://wa.me/?text='+encodeURIComponent(t);$('shFb').href='https://www.facebook.com/sharer/sharer.php?u='+encodeURIComponent(location.origin);
  setLink('shIg',CFG.INSTAGRAM);setLink('fIg',CFG.INSTAGRAM);setLink('fFb',CFG.FACEBOOK);
  var w=CFG.WHATSAPP?'https://wa.me/'+CFG.WHATSAPP+'?text='+encodeURIComponent('Hi StaffWale, mujhe booking ki jaankari chahiye.'):'';setLink('fWa',w);setLink('waFab',w);
}

/* ---------- Setup ---------- */
function fillProfile(){
  $('fName').value=ME.name||'';$('fMobile').value=ME.mobile;$('fMobile').readOnly=true;$('fCity').value=ME.city||'Jaipur';
  if(ME.age)$('fAge').value=ME.age;if(ME.vehicle)$('fVeh').value=ME.vehicle;$('fPost').value=ME.post||'Waiter';$('fExp').value=ME.exp||0;$('pid').textContent=ME.id.slice(0,6).toUpperCase();
}
function refreshAll(){return Promise.all([loadMe(),loadJobs(),loadStaff()]).then(function(){rSub();hCalc();rRef();return Promise.all([rO(),rB()]).then(rW)})}

async function init(){
  var s=(await sb.auth.getSession()).data.session;if(!s){location.replace('index.html');return}
  if(!(await loadMe())){toast('Profile nahi mili. Dobara login karein.');await sb.auth.signOut();location.replace('index.html');return}
  var a='';for(var i=18;i<=60;i++)a+='<option'+(i===25?' selected':'')+'>'+i+'</option>';$('fAge').innerHTML=a;
  $('fVeh').parentElement.insertAdjacentHTML('afterend','<label>Aapki post<select id="fPost">'+opts()+'</select></label><label>Experience (saal)<input id="fExp" type="number" min="0" max="40"></label>');
  $('fPhoto').parentElement.style.display='none';
  var o='';for(var k=1;k<=12;k++)o+='<option'+(k===4?' selected':'')+'>'+k+'</option>';$('hHrs').innerHTML=o;
  ['hRole','pRole'].forEach(function(i){$(i).innerHTML=opts()});$('sRole').innerHTML='<option>All</option>'+opts();
  $('hDate').min=today();$('pDate').min=today();$('sDate').value=today();$('sDate').min=today();
  $('who').textContent=ME.name+' · '+ME.role;$('who').classList.remove('hid');$('authBtn').textContent='Logout';
  if(ME.is_admin){var mn=document.querySelector('.menu');if(mn)mn.insertAdjacentHTML('beforeend','<a href="admin.html">Admin</a>')}
  $('dashEl').classList.remove('locked');$('dashEl').classList.toggle('cust',!isPartner());
  document.querySelector('.dtab[data-p="'+(isPartner()?'Profile':'Orders')+'"]').click();
  try{PC=await rpc('public_config')}catch(e){}
  fillProfile();
  await refreshAll();rR();
  setInterval(function(){loadJobs();loadStaff()},30000);
}

/* ---------- Events ---------- */
document.addEventListener('click',function(e){
  var t=e.target.closest('.dtab,.stab');
  if(t){var d=t.classList.contains('dtab');
    document.querySelectorAll(d?'.dtab':'.stab').forEach(function(b){b.setAttribute('aria-selected',b===t)});
    document.querySelectorAll(d?'.pane':'.spane').forEach(function(p){p.classList.toggle('on',p.id===(d?'pane-':'sp-')+t.dataset.p)});return}
  var r=e.target.closest('.role');if(r){flt=r.dataset.r;rChips();rJobs();$('jobs').scrollIntoView();return}
  var c=e.target.closest('.chip');if(c){flt=c.dataset.f;rChips();rJobs();return}
  var c2=e.target.closest('.chip2');if(c2){txf=c2.dataset.t;rW();return}
  var a=e.target.closest('[data-acc]');if(a){tab(async function(){await rpc('accept_job',{p_id:a.dataset.acc});toast('Booking accept ho gayi. Dashboard → Bookings dekhein.');await Promise.all([loadJobs(),rB()])});return}
  var co=e.target.closest('[data-co]');if(co){if(!confirm('Booking cancel karein?'))return;tab(async function(){var tok=(await sb.auth.getSession()).data.session.access_token,r=await api('cancel-booking',{job_id:co.dataset.co},tok);toast(r.refund==='done'?'Booking cancel. Refund bhej diya gaya (5-7 din mein aayega).':(r.refund==='pending'?'Booking cancel. Refund process mein hai.':'Booking cancel ho gayi.'));await Promise.all([rO(),loadJobs()])});return}
  var pj=e.target.closest('[data-pay]');if(pj){tab(async function(){await payJob(pj.dataset.pay);await Promise.all([rO(),loadJobs()])});return}
  var cf=e.target.closest('[data-cf]');if(cf){tab(async function(){await rpc('confirm_complete',{p_id:cf.dataset.cf});toast('Booking complete. Partner ko payment mil gaya.');await rO()});return}
  var pc=e.target.closest('[data-pc]');if(pc){tab(async function(){await rpc('partner_cancel',{p_id:pc.dataset.pc});toast('Booking cancel ho gayi.');await Promise.all([rB(),loadJobs()])});return}
  var st=e.target.closest('[data-st]');if(st){tab(function(){return rST(st.dataset.st)});return}
  if(e.target.closest('[data-sub]'))openSub();
});
$('authBtn').onclick=async function(){await sb.auth.signOut();location.href='index.html'};
$('jq').addEventListener('input',rJobs);$('jsort').addEventListener('change',rJobs);
['hRole','hHrs','hBudget'].forEach(function(i){$(i).addEventListener('input',hCalc)});
$('xPlus').onclick=function(){XT=Math.min(2000,XT+100);hCalc()};$('xMinus').onclick=function(){XT=Math.max(0,XT-100);hCalc()};
['sRole','sFree'].forEach(function(i){$(i).addEventListener('input',rS)});
$('sDate').addEventListener('input',function(){tab(loadStaff)});
$('stClose').onclick=function(){$('stDlg').close()};$('subClose').onclick=function(){$('subDlg').close()};
$('subPay').onclick=function(){tab(async function(){
    if(typeof Razorpay==='undefined')throw new Error('Razorpay load nahi hua. Internet check karein.');
    var tok=(await sb.auth.getSession()).data.session.access_token,o=await api('create-order',{},tok);
    await new Promise(function(res,rej){
      var z=new Razorpay({key:o.key_id,order_id:o.order_id,amount:o.amount,currency:'INR',name:'StaffWale',description:'Staff numbers - 30 din',prefill:{contact:ME.mobile,name:ME.name},theme:{color:'#f2c200'},
        handler:function(r){api('verify-payment',r,tok).then(res,rej)},
        modal:{ondismiss:function(){rej(new Error('Payment cancel ho gaya.'))}}});
      z.on('payment.failed',function(x){rej(new Error('Payment fail hui: '+((x.error&&x.error.description)||'')))});
      z.open()});
  $('subDlg').close();await loadMe();rS();rSub();if($('stDlg').open)await rST(curSt);toast('Subscription active. Numbers unlock ho gaye.')})};

$('homeForm').addEventListener('submit',function(e){e.preventDefault();tab(async function(){
  var hr=hrsRole(),res=await rpc('create_job',{p_kind:'home',p_role:$('hRole').value,p_venue:null,p_city:$('hCity').value.trim(),p_address:$('hAddr').value.trim(),p_date:$('hDate').value,p_slot:$('hTime').value,p_hours:hr?+$('hHrs').value:null,p_guests:+$('hGuests').value,p_notes:$('hNotes').value.trim()||null,p_budget:hr?null:(+$('hBudget').value||0),p_extra:hr?XT:0});
  say('hOk','Booking ban gayi. Aap dein: ₹'+res.customer_pays+(res.discounted?' (₹'+(res.fare-res.customer_pays)+' discount)':'')+'. Payment ke baad partner ko dikhegi.');
  e.target.reset();XT=0;$('hCity').value='Jaipur';$('hGuests').value=4;$('hHrs').value=4;
  await refreshAll();
  try{await payJob(res.id)}catch(err){toast((err.message||'Payment nahi hui')+' Meri Booking mein "Pay" dabakar dobara try karein.')}
  await refreshAll();
})});
$('post').addEventListener('submit',function(e){e.preventDefault();tab(async function(){
  await rpc('create_job',{p_kind:'venue',p_role:$('pRole').value,p_venue:$('pVenue').value.trim(),p_city:$('pCity').value.trim(),p_address:null,p_date:$('pDate').value,p_slot:null,p_hours:null,p_guests:null,p_notes:null,p_budget:+$('pPay').value,p_extra:0});
  say('pOk','Job post ho gayi. Live jobs mein dekhein.');e.target.reset();$('pCity').value='Jaipur';await Promise.all([loadJobs(),rO()]);
})});
$('fPer').addEventListener('submit',function(e){e.preventDefault();tab(async function(){
  var r=await sb.from('profiles').update({name:$('fName').value.trim(),city:$('fCity').value.trim(),age:+$('fAge').value,vehicle:$('fVeh').value,post:$('fPost').value,exp:+$('fExp').value||0}).eq('id',ME.id);
  if(r.error)throw new Error(r.error.message);say('fPerOk','Profile save ho gayi.');await loadMe();$('who').textContent=ME.name+' · '+ME.role;loadStaff();
})});
$('lkBank').onclick=function(){$('bankBox').classList.toggle('hid');$('wdBox').classList.add('hid')};
$('lkWd').onclick=function(){$('wdBox').classList.toggle('hid');$('bankBox').classList.add('hid')};
$('bankBox').addEventListener('submit',function(e){e.preventDefault();tab(async function(){
  await rpc('save_bank',{p_holder:$('bName').value.trim(),p_account:$('bAcc').value.trim(),p_ifsc:$('bIfsc').value.trim(),p_upi:$('bUpi').value.trim()});
  $('bAcc').value='';say('wMsg','Bank details save ho gayi.');$('bankBox').classList.add('hid');
})});
$('wdBox').addEventListener('submit',function(e){e.preventDefault();tab(async function(){
  await rpc('request_payout',{p_amount:Math.floor(+$('wdAmt').value)});
  $('wdAmt').value='';$('wdBox').classList.add('hid');say('wMsg','Withdraw request bhej di gayi. Payouts tab mein dekhein.');await loadMe();await rW();
})});
$('revForm').addEventListener('submit',function(e){e.preventDefault();tab(async function(){
  await rpc('add_review',{p_stars:+$('rvStar').value,p_body:$('rvTxt').value});e.target.reset();toast('Review ke liye shukriya!');await rR();
})});
$('refCopy').onclick=function(){var c=ME&&ME.ref_code;if(!c)return;try{navigator.clipboard.writeText(c).then(function(){toast('Code copy ho gaya: '+c)},function(){toast('Code: '+c)})}catch(x){toast('Code: '+c)}};

init();
})();
