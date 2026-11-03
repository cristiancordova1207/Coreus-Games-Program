// Red Carpet · panel
const $ = (s) => document.querySelector(s);
const $$ = (s) => [...document.querySelectorAll(s)];
const api = (url, body) => fetch(url, body !== undefined ? { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) } : {})
  .then(async (r) => ({ httpOk: r.ok, ...(await r.json().catch(() => ({}))) }));
let S = null, L = 'es', view = 'live', lastLog = 0, gifts = 0, mounted = false;

const t = (k, vars) => { let s = (I18N[L] || I18N.es)[k] ?? I18N.es[k] ?? k; for (const v in vars || {}) s = s.replace('{' + v + '}', vars[v]); return s; };
const errText = (e) => (e ? t('err_' + e) : '');
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
function applyI18n() {
  document.documentElement.lang = L;
  $$('[data-i18n]').forEach((el) => (el.textContent = t(el.dataset.i18n)));
  $$('[data-i18n-ph]').forEach((el) => (el.placeholder = t(el.dataset.i18nPh)));
  $('#langSel').value = L;
}

// ---------- animaciones ----------
function jelly(el) { el.classList.remove('wobble'); void el.offsetWidth; el.classList.add('wobble'); }
document.addEventListener('pointerdown', (e) => {
  const b = e.target.closest('.btn');
  if (!b) return;
  jelly(b);
  const r = b.getBoundingClientRect(), g = document.createElement('span');
  g.className = 'goo'; g.style.left = e.clientX - r.left + 'px'; g.style.top = e.clientY - r.top + 'px';
  b.appendChild(g); setTimeout(() => g.remove(), 700);
});
function confetti(el, n = 28) {
  const r = el.getBoundingClientRect(), cols = ['#25f4ee', '#fe2c55', '#8b5cf6', '#fbbf24', '#4ade80'];
  for (let i = 0; i < n; i++) {
    const c = document.createElement('i');
    c.className = 'confetti';
    c.style.left = r.left + r.width / 2 + 'px'; c.style.top = r.top + r.height / 2 + 'px';
    c.style.background = cols[i % cols.length];
    c.style.setProperty('--dx', (Math.random() - 0.5) * 360 + 'px');
    c.style.setProperty('--dy', -60 - Math.random() * 220 + 'px');
    c.style.setProperty('--r', Math.random() * 720 + 'deg');
    document.body.appendChild(c); setTimeout(() => c.remove(), 1200);
  }
}
setInterval(() => { // notas musicales que suben por el fondo
  if (document.hidden) return;
  const n = document.createElement('span');
  n.className = 'note'; n.textContent = ['📸', '🎬', '✨', '⭐', '🌹'][Math.floor(Math.random() * 5)];
  n.style.left = Math.random() * 100 + 'vw'; n.style.animationDuration = 9 + Math.random() * 7 + 's';
  document.body.appendChild(n); setTimeout(() => n.remove(), 17000);
}, 1600);
function toast(msg) {
  const d = document.createElement('div'); d.className = 'toast'; d.textContent = msg;
  document.body.appendChild(d); setTimeout(() => d.remove(), 2600);
}

// ---------- navegación ----------
function show(v) {
  view = v;
  $$('#nav button').forEach((b) => b.classList.toggle('on', b.dataset.v === v));
  $$('.view').forEach((s) => (s.hidden = s.id !== 'v-' + v));
}
$$('#nav button').forEach((b) => (b.onclick = () => show(b.dataset.v)));
$('#langSel').onchange = () => { L = $('#langSel').value; api('/api/config', { lang: L }); applyI18n(); render(); };
$$('[data-lang]').forEach((b) => (b.onclick = () => { L = b.dataset.lang; api('/api/config', { lang: L }); $('#sLang').hidden = true; applyI18n(); render(); }));

// ---------- estado ----------
async function refresh() {
  try { S = await api('/api/state'); } catch { return; }
  renderAuto(S);
  renderPhone(S);
  if (!mounted) {
    mounted = true;
    L = S.cfg.lang || (navigator.language || 'es').slice(0, 2);
    if (!I18N[L]) L = 'en';
    if (!S.cfg.lang) $('#sLang').hidden = false;
    $('#tt').value = S.cfg.tiktok_user ? '@' + S.cfg.tiktok_user : '';
    $('#code').value = S.cfg.code || '';
    applyI18n();
    checkUpdate();
  }
  render();
}

let wantPlans = false;
function render() {
  if (!S) return;
  const A = S.account, P = A.profile;
  $('#ver').textContent = 'v' + A.version;
  // pantallas: login -> planes -> panel
  $('#sLogin').hidden = A.logged;
  // en prueba también se puede comprar: el botón Comprar de la cuenta abre esta pantalla (wantPlans)
  if (P && (P.plan === 'monthly' || P.plan === 'lifetime' || P.role === 'admin')) wantPlans = false;
  const plans = A.logged && (!A.allowed || wantPlans);
  $('#sPlans').hidden = !plans;
  $('#pBack').hidden = !A.allowed;
  $('#pTrial').hidden = !!A.allowed;
  $('#app').hidden = !A.logged;
  if (plans) renderPlans();
  if (!P) return;
  $('#navAdmin').hidden = !A.admin;
  premiumLock(P);
  $('#uAv').textContent = P.username[0].toUpperCase();
  $('#uName').textContent = P.username;
  $('#uPlan').textContent = planName(P);
  $('#uPlan').onclick = () => { if (P.onTrial) { wantPlans = true; render(); } };
  $('#uPlan').style.cursor = P.onTrial ? 'pointer' : '';

  const st = S.status;
  $('#liveCard').classList.toggle('live', st === 'live');
  $('#dTT').className = 'dot ' + (st === 'live' ? 'on' : st === 'connecting' ? 'wait' : '');
  $('#sTT').textContent = t(st === 'live' ? 'ttLive' : st === 'connecting' ? 'ttWait' : 'ttOff');
  const c = $('#connect');
  c.textContent = t(st === 'off' ? 'connect' : 'disconnect');
  c.classList.toggle('is-live', st !== 'off');
  $('#ttErr').textContent = S.error === 'offline' ? t('err_offline_live') : S.error || '';
  const game = S.studio ? 'gameStudio' : S.cloud ? 'gameCloud' : 'gameOff';
  $('#dG').className = 'dot ' + (S.studio || S.cloud ? 'on' : '');
  $('#sG').textContent = t(game);
  $('#nAv').textContent = S.avatars;
  $('#nQ').textContent = S.queue.length;
  $('#nGift').textContent = gifts;

  // juego
  const link = S.cfg.link;
  $$('#seg button').forEach((b) => b.classList.toggle('on', b.dataset.l === link));
  const on = $('#seg button.on'), bg = $('#seg .pillbg');
  if (on) { bg.style.left = on.offsetLeft + 'px'; bg.style.width = on.offsetWidth + 'px'; }
  $('#lAuto').hidden = link !== 'auto'; $('#lCode').hidden = link !== 'code';
  if (document.activeElement !== $('#rbx')) $('#rbx').value = P.robloxUser || '';
  $('#dC').className = 'dot ' + (S.cloud ? 'on' : '');
  const ready = S.hasKey && (link === 'code' ? !!S.cfg.code : !!P.robloxId);
  $('#sC').textContent = t(S.cloud ? 'cloudOk' : ready ? 'cloudWait' : 'cloudOff');
  $('#lErr2').textContent = S.cloudError && !['offline', 'net', 'no_key'].includes(S.cloudError) ? errText('cloud_' + S.cloudError) : '';
  $('#ckey').placeholder = t(S.hasKey ? 'keySaved' : 'keyPh');
  $('#fameOn').classList.toggle('on', S.cfg.fame.on);
  if (document.activeElement !== $('#fameRate')) $('#fameRate').value = S.cfg.fame.rate;
  $('#fameTop').innerHTML = S.fameTop.map((e, i) => `<div><time>${i + 1}</time><span><b>${esc(e.u)}</b> · ${e.f.toLocaleString()} 👤</span></div>`).join('');

  // actividad
  const newest = S.log[0]?.t || 0;
  if (newest !== lastLog) {
    const fresh = S.log.filter((l) => l.t > lastLog);
    if (lastLog) for (const l of fresh) if (l.kind === 'gift') { gifts++; confetti($('#nGift')); }
    lastLog = newest;
    $('#log').innerHTML = S.log.length
      ? S.log.map((l) => `<div class="${l.kind}"><time>${new Date(l.t * 1000).toLocaleTimeString()}</time><span>${esc(l.text)}</span></div>`).join('')
      : `<div class="empty">${t('emptyLog')}</div>`;
  }
  renderAccount(P);
  renderShow();
}

function planName(P) {
  if (P.role === 'admin') return t('planAdmin');
  if (P.plan === 'lifetime') return t('planLifetime');
  if (P.plan === 'monthly') return t('planMonthly');
  if (P.onTrial) return t('minutesLeft', { n: Math.ceil(P.trialSeconds / 60) });
  return t('planNone');
}
function renderAccount(P) {
  $('#accSub').textContent = P.username;
  const until = P.plan === 'monthly' && P.planUntil ? ` · ${t('until')} ${new Date(P.planUntil).toLocaleDateString()}` : '';
  $('#accCard').innerHTML = `<h3><span class="ic">💎</span>${esc(planName(P))}${until}</h3>
    <div class="row">${P.onTrial ? `<button class="btn btn-primary btn-sm jelly" id="accBuy">💎 ${t('buy')}</button>` : ''}${P.plan === 'monthly' ? `<button class="btn btn-ghost btn-sm jelly" id="portal">${t('manage')}</button>` : ''}
    <button class="btn btn-ghost btn-sm jelly" id="out">${t('logout')}</button></div>`;
  $('#out').onclick = logout;
  if ($('#accBuy')) $('#accBuy').onclick = () => { wantPlans = true; render(); };
  if ($('#portal')) $('#portal').onclick = () => api('/api/account/portal', {});
}
function renderPlans() {
  const pr = S.account.prices, P = S.account.profile;
  $('#pEnded').hidden = !(P && P.trialEnded);
  if (!pr) { $('#pPrice').textContent = '…'; return; }
  const m = pr.monthly;
  $('#pName').textContent = t('monthly');
  $('#pPrice').innerHTML = (m.launch && m.regular > m.amount ? `<s style="opacity:.5;font-size:.6em">$${m.regular}</s> ` : '')
    + `$${m.amount} <small>${m.firstMonth ? t('firstMonth') : t('perMonth')}</small>`;
  $('#pLeft').textContent = m.launch ? t('leftN', { n: pr.launchLeft, off: Math.round((1 - m.amount / m.regular) * 100), regular: m.regular }) : '';
}

// ---------- acciones ----------
let mode = 'login';
$$('.tabs2 button').forEach((b) => (b.onclick = () => {
  mode = b.dataset.mode;
  $$('.tabs2 button').forEach((x) => x.classList.toggle('on', x === b));
  $('#lConf').hidden = mode !== 'register';
  $('#lGo').textContent = t(mode);
}));
$('#lGo').onclick = async () => {
  $('#lErr').textContent = '';
  const r = await api('/api/account/' + mode, { username: $('#lUser').value.trim(), password: $('#lPass').value, confirm: $('#lConf').value });
  if (r.error) $('#lErr').textContent = errText(r.error) + (r.bannedUntil ? ' · ' + new Date(r.bannedUntil).toLocaleString() : '') + (r.banMsg ? ' — ' + r.banMsg : '');
  else { $('#lPass').value = $('#lConf').value = ''; confetti($('#lGo')); }
  refresh();
};
['#lUser', '#lPass', '#lConf'].forEach((s) => ($(s).onkeydown = (e) => { if (e.key === 'Enter') $('#lGo').click(); }));
async function logout() { await api('/api/account/logout', {}); refresh(); }
$('#pLogout').onclick = logout;
$('#pBack').onclick = () => { wantPlans = false; render(); };
// Pack Premium: AFK, ajustes del desfile, Live Checker y reinicio del LIVE (los overlays son gratis). En la prueba están abiertos y no se dice nada;
// con suscripción y sin el pack salen con candado y un botón para comprarlo (pago único)
function premiumLock(P) {
  const locked = !P.premium;
  for (const box of [$('#phCode').closest('.card'), $('#afk').closest('.card'), $('#walkGap').closest('.card')]) {
    let l = box.querySelector(':scope > .pl-lock');
    box.classList.toggle('pl-locked', locked);
    if (!locked) { if (l) l.remove(); continue; }
    if (!l) {
      l = document.createElement('div');
      l.className = 'pl-lock';
      l.innerHTML = `<div class="pl-in"><div class="pl-ic">✨</div><b>${t('premTitle')}</b><span>${t('premSub')}</span>
        <button class="btn btn-primary jelly">${t('premBuy')}</button><span class="err"></span></div>`;
      l.querySelector('button').onclick = async () => { const r = await api('/api/account/checkout_premium', {}); l.querySelector('.err').textContent = errText(r.error); };
      box.append(l);
    }
  }
}
$('#pBuy').onclick = async () => { const r = await api('/api/account/checkout', {}); $('#pErr').textContent = errText(r.error); };
$('#pCheck').onclick = async () => { await api('/api/account/refresh', {}); refresh(); };
$('#pTrial').onclick = () => api('/api/open/trial', {});
$('#openDiscord').onclick = () => api('/api/open/discord', {});
$('#openGame').onclick = () => api('/api/open/game', {});

$('#connect').onclick = async () => {
  $('#ttErr').textContent = '';
  if (S && S.status !== 'off') { await api('/api/disconnect', {}); return refresh(); }
  const r = await api('/api/connect', { user: $('#tt').value });
  if (r.error) $('#ttErr').textContent = errText(r.error);
  else confetti($('#connect'));
  refresh();
};
$('#tt').onkeydown = (e) => { if (e.key === 'Enter') $('#connect').click(); };
$('#tGo').onclick = async () => {
  const r = await api('/api/test', { name: $('#tName').value, nick: $('#tName').value });
  $('#tErr').textContent = errText(r.error);
  refresh();
};
$('#tName').onkeydown = (e) => { if (e.key === 'Enter') $('#tGo').click(); };
$('#tMany').onclick = async () => {
  for (const n of ['Builderman', 'Roblox', 'Shedletsky', 'Linkmon99', 'Stickmasterluke']) await api('/api/test', { name: n, nick: n });
  refresh();
};

$$('#seg button').forEach((b) => (b.onclick = async () => { await api('/api/config', { link: b.dataset.l }); refresh(); }));
$('#rbxSave').onclick = async () => {
  const r = await api('/api/roblox', { user: $('#rbx').value });
  $('#lErr2').textContent = errText(r.error);
  if (!r.error) toast(t('saved'));
  refresh();
};
$('#ckeySave').onclick = async () => {
  const r = await api('/api/cloudkey', { key: $('#ckey').value });
  $('#lErr2').textContent = r.error ? errText('cloud_' + r.error) : '';
  if (!r.error) { $('#ckey').value = ''; toast(t('saved')); }
  refresh();
};
$('#fameOn').onclick = () => api('/api/config', { fame: { on: !S.cfg.fame.on } }).then(refresh);
$('#fameRate').onchange = () => api('/api/config', { fame: { rate: Number($('#fameRate').value) } }).then(refresh);
$('#fameReset').onclick = () => api('/api/config', { fame: { reset: true } }).then(refresh);
$('#codeSave').onclick = async () => {
  const r = await api('/api/config', { code: $('#code').value });
  $('#lErr2').textContent = errText(r.error);
  if (!r.error) toast(t('saved'));
  refresh();
};

// admin
$('#adGrant').onclick = async () => {
  const r = await api('/api/admin', { action: 'trial_set', username: $('#adGU').value.trim(), minutes: Number($('#adGM').value) });
  $('#adGrantMsg').textContent = r.error ? errText(r.error) : `✓ ${r.user.username}: ${Math.round(r.user.trial_seconds / 60)} min`;
};
$('#adTrial').onclick = async () => {
  const r = await api('/api/admin', { action: 'trial_create', username: $('#adTU').value.trim(), password: $('#adTP').value, minutes: Number($('#adTM').value) });
  $('#adTrialMsg').textContent = r.error ? errText(r.error) : `✓ ${r.user.username} · ${Math.round(r.user.trial_seconds / 60)} min`;
};

// eventos automáticos: encender/apagar, lanzar a mano y lo aprendido (monedas medias en los 2 min siguientes)
$('#adAuto').onchange = (e) => api('/api/auto', { on: e.target.checked }).then(refresh);
document.querySelectorAll('[data-auto]').forEach((b) => b.onclick = async () => {
  const r = await api('/api/auto', { kind: b.dataset.auto, size: Number($('#adRacha').value) });
  $('#adAutoMsg').textContent = r.error ? t('autoNoGame') : '✓ ' + r.text;
});
// atasco artificial: lista "usuarioRoblox @tiktok" (uno por línea), automático cada X min y botón para lanzarlo ya
async function jamGo() {
  const r = await api('/api/jam', { go: true });
  toast(r.error ? t('autoNoGame') : `🚧 +${r.added}`);
  refresh();
}
$('#tJam').onclick = $('#jamGo2').onclick = jamGo;
$('#jamAuto').onchange = (e) => api('/api/jam', { auto: e.target.checked, every: Number($('#jamEvery').value) }).then(refresh);
$('#jamEvery').onchange = () => api('/api/jam', { every: Number($('#jamEvery').value) });
// Rush: libreta con una fila por persona (Roblox | @TikTok); se guarda sola al cambiar algo
const jamRows = () => [...$('#jamList').querySelectorAll('.nb-row')].map((r) => [r.querySelector('.nb-r').value.trim().replace(/^@/, ''),
  r.querySelector('.nb-t').value.trim().replace(/^@/, '')]).filter((u) => u[0]);
function jamDraw(users) {
  $('#jamList').innerHTML = users.map(([n, u], i) => `<div class="nb-row"><span class="nb-n">${i + 1}</span>
    <input class="nb-r" value="${esc(n)}" placeholder="Roblox" spellcheck="false" maxlength="20">
    <input class="nb-t" value="${esc(u ? '@' + u : '')}" placeholder="@tiktok" spellcheck="false" maxlength="25">
    <button class="nb-x" title="${t('del')}">✕</button></div>`).join('') || `<div class="nb-empty">${t('jamEmpty')}</div>`;
  $('#jamCount').textContent = users.length;
}
let jamTimer;
function jamSave(redraw) {
  clearTimeout(jamTimer);
  jamTimer = setTimeout(async () => {
    const users = jamRows();
    await api('/api/jam', { users });
    $('#jamList').dataset.v = JSON.stringify(users);
    if (redraw) jamDraw(users);
    $('#jamCount').textContent = users.length;
  }, 250);
}
$('#jamList').onchange = () => jamSave(false);
$('#jamList').onclick = (e) => { if (e.target.closest('.nb-x')) { e.target.closest('.nb-row').remove(); jamSave(true); } };
$('#jamList').addEventListener('paste', (e) => { // pegar varias líneas «roblox @tiktok» de golpe: una fila cada una
  const txt = (e.clipboardData || window.clipboardData).getData('text');
  if (!txt.includes('\n')) return;
  e.preventDefault();
  const add = txt.split('\n').map((l) => l.trim().split(/\s+/)).filter((p) => p[0]).map((p) => [p[0].replace(/^@/, ''), (p[1] || '').replace(/^@/, '')]);
  jamDraw([...jamRows(), ...add]);
  jamSave(true);
});
$('#jamAdd').onclick = () => {
  const users = jamRows();
  jamDraw([...users, ['', '']]);
  const ins = $('#jamList').querySelectorAll('.nb-r');
  ins[ins.length - 1].focus();
};
// Live Checker (Pack Premium): código para la app del móvil, aviso de prueba y reinicio del LIVE
$('#phNew').onclick = async () => {
  if ($('#phCode').textContent && !confirm(t('phoneNewQ'))) return;
  await api('/api/phone', { new: true }); refresh();
};
$('#phTest').onclick = () => api('/api/phone', { test: true }).then(() => toast('🔔 ' + t('phoneSent')));
$('#phApk').onclick = () => api('/api/open/apk', {});
$('#rsOn').onchange = (e) => api('/api/phone', { restart: { on: e.target.checked, at: Number($('#rsAt').value) } }).then(refresh);
$('#rsWarn').onchange = (e) => api('/api/phone', { restart: { on_warn: e.target.checked } }).then(refresh);
$('#rsGifts').onchange = (e) => api('/api/phone', { restart: { on_gifts: e.target.checked } }).then(refresh);
$('#rsCaptcha').onchange = (e) => api('/api/phone', { restart: { captcha: e.target.checked } }).then(refresh);
$('#rsAt').onchange = () => api('/api/phone', { restart: { at: Number($('#rsAt').value) } });
$('#rsTry').onclick = async () => {
  $('#rsMsg').textContent = '…';
  const r = await api('/api/phone', { try: true });
  $('#rsMsg').textContent = r.result === 'ok' ? '✓ ' + t('restartTryOk') : '✗ ' + r.result;
};
$('#rsNow').onclick = () => confirm(t('restartNowQ')) && api('/api/phone', { now: true });
$('#rsElev').onclick = () => api('/api/phone', { elevate: true });
function renderPhone(S) {
  const P = S.phone;
  $('#phCode').textContent = P.code;
  $('#phNew').textContent = t(P.code ? 'phoneNew' : 'phoneOn');
  $('#phTest').hidden = !P.code;
  $('#phDot').className = 'dot' + (P.ok ? ' on' : '');
  $('#phState').textContent = P.code ? t(P.ok ? 'phoneOk' : 'phoneWait') : t('phoneOff');
  if (!P.premium) return;  // con candado: se ve, pero no se toca
  $('#rsOn').checked = !!P.restart.on;
  $('#rsWarn').checked = !!P.restart.on_warn;
  $('#rsGifts').checked = !!P.restart.on_gifts;
  $('#rsCaptcha').checked = !!P.restart.captcha;
  if (!typing($('#rsAt'))) $('#rsAt').value = P.restart.at;
  $('#rsElev').hidden = P.elevated;
  if (P.restarting) $('#rsMsg').textContent = '🔁 ' + t('restartBusy');
  else if (!P.elevated) $('#rsMsg').textContent = '⚠️ ' + t('restartNeedAdmin');
  else if (P.restart.on && P.elapsed != null) $('#rsMsg').textContent = `⏱️ ${Math.max(0, Math.round(P.restart.at - P.elapsed / 60))} min`;
}
function renderAuto(S) {
  $('#tJam').hidden = !S.auto;
  if (!S.auto) return;
  const j = S.cfg.jam, list = JSON.stringify(j.users);
  if ($('#jamList').dataset.v !== list && !$('#jamList').contains(document.activeElement)) { $('#jamList').dataset.v = list; jamDraw(j.users); }
  $('#jamAuto').checked = !!j.auto;
  if (!typing($('#jamEvery'))) $('#jamEvery').value = j.every;
  $('#jamMsg').textContent = `🚧 ${S.auto.jam}/140` + (j.auto && S.auto.jamNext ? ` · ⏱️ ${Math.ceil(S.auto.jamNext / 60)} min` : '');
  $('#adAuto').checked = !!S.cfg.auto.on;
  $('#adAutoStats').textContent = Object.entries(S.auto.stats).map(([k, [n, c]]) => `${k}: ${Math.round(c / n)} 🪙 ×${n}`).join(' · ') || t('autoNoData');
}

$('#adSiteGo').onclick = () => cfgSet({ site: $('#adSite').value }).then(() => toast(t('saved')));

// actualizaciones
// con el programa abierto se mira cada 5 min: aviso abajo con botón Actualizar; si es obligatoria, a los 10 min se instala sola
let updTimer = null;
setInterval(async () => {
  if (!$('#sUpdate').hidden || updTimer) return;
  const u = await api('/api/update').catch(() => ({}));
  if (!u.available) return;
  const bar = document.createElement('div');
  bar.className = 'upd-bar';
  bar.innerHTML = `<span>✨ <b>v${u.latest}</b> · <span class="upd-t"></span></span><button class="btn btn-primary btn-sm jelly">${t('update')}</button>`;
  bar.querySelector('button').onclick = () => { bar.remove(); checkUpdate(true); };
  document.body.append(bar);
  const end = Date.now() + 10 * 60e3;
  const tick = () => {
    const s = Math.max(0, Math.round((end - Date.now()) / 1000));
    bar.querySelector('.upd-t').textContent = u.required ? t('updSoon').replace('{t}', `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`) : t('newVersion');
    if (u.required && s <= 0) { bar.remove(); checkUpdate(true); } else if (bar.isConnected) setTimeout(tick, 1000);
  };
  updTimer = 1; tick();
}, 5 * 60e3);
async function checkUpdate(now) {
  const u = await api('/api/update');
  if (!u.available) return;
  if (now === true) u.required = true; // desde el aviso: instalar ya
  $('#upVer').textContent = `v${u.current} → v${u.latest}`;
  $('#upNotes').textContent = u.notes;
  $('#sUpdate').hidden = false;
  if (u.required) { $('#upLater').hidden = true; runUpdate(); } // obligatoria: se instala sola
}
$('#upLater').onclick = () => ($('#sUpdate').hidden = true);
$('#upGo').onclick = runUpdate;
// descarga en segundo plano: el servidor cuenta los bytes en /api/update/progress y luego se reinicia solo
async function runUpdate() {
  const busy = (b) => { $('#upGo').disabled = $('#upLater').disabled = b; };
  busy(true);
  $('#upMsg').textContent = '⏬ …';
  const r = await api('/api/update', { go: true });
  if (r.error) { $('#upMsg').textContent = r.error; busy(false); return; }
  $('#upBar').hidden = false;
  const tick = async () => {
    let p;
    try { p = await (await fetch('/api/update/progress')).json(); } catch { // el programa se cerró para instalar
      $('#upBar i').style.width = '100%'; $('#upMsg').textContent = '🔄 …'; setTimeout(() => window.close(), 4000); return;
    }
    if (p.state === 'error') { $('#upMsg').textContent = '⚠️ ' + p.error; $('#upBar').hidden = true; busy(false); return; }
    const pct = p.state === 'restarting' ? 100 : p.total ? Math.min(100, (p.done / p.total) * 100) : 0;
    $('#upBar i').style.width = pct + '%';
    $('#upMsg').textContent = p.state === 'restarting' ? '🔄 …' : `⏬ ${Math.round(pct)}% · ${(p.done / 1e6).toFixed(1)} / ${(p.total / 1e6 || 0).toFixed(1)} MB`;
    setTimeout(tick, 300);
  };
  tick();
}



// ---------- Red Carpet: cola, regalos, overlays, juego ----------
const MODE_ICON = { skip: '⚡', priority: '🌹', cinematic: '🎬', photo: '📸', float: '🫧', party: '🎉', giant: '🗿', universe: '🌌' };
const FONTS = ['Lilita One', 'Fredoka', 'Luckiest Guy', 'Bangers', 'Poppins', 'Montserrat', 'Anton', 'Bebas Neue', 'Baloo 2', 'Rubik', 'Permanent Marker', 'Press Start 2P'];
const OV_VIEWS = ['all', 'title', 'lobby', 'now', 'queue', 'modes', 'donors', 'alerts'];
let ovView = 'title', lastModes = '', lastQueue = '', lastEls = '';
const cfgSet = (data) => api('/api/config', data).then(refresh);
const typing = (el) => document.activeElement === el;

function renderShow() {
  // cola
  const now = S.now && Date.now() / 1000 - S.now.t < 15 ? S.now : null;
  $('#nowWalk').textContent = now ? t('walkingNow', { n: now.n + (now.cine ? ' 🎬' : '') }) : '';
  $('#paused').classList.toggle('on', !S.cfg.paused);
  const qk = JSON.stringify(S.queue);
  if (qk !== lastQueue) {
    lastQueue = qk;
    $('#queue').innerHTML = S.queue.length ? S.queue.map((e, i) => `<div class="${e.prio || e.cine ? 'gift' : 'comment'}" style="display:flex;align-items:center;gap:8px">
        <time>${i + 1}</time><span style="flex:1"><b>${esc(e.n)}</b> <small class="hint">@${esc(e.u || '')}</small> ${e.prio ? '🌹' + (e.prio > 1 ? ' x' + e.prio : '') : ''}${e.cine ? '🎬' + (e.cine > 1 ? ' x' + e.cine : '') : ''}</span>
        <button class="icon-btn" data-q="top" data-n="${esc(e.n)}" title="${t('top')}">⬆</button>
        <button class="icon-btn" data-q="walk" data-n="${esc(e.n)}" title="${t('walkNow')}">▶</button>
        <button class="icon-btn" data-q="remove" data-n="${esc(e.n)}" title="${t('remove')}">✕</button></div>`).join('')
      : `<div class="empty">${t('emptyQueue')}</div>`;
  }
  // regalos (sólo se repinta si cambia, para no pisar lo que se está escribiendo)
  const mk = JSON.stringify(S.modes) + L;
  if (mk !== lastModes) {
    lastModes = mk;
    // los mismos controles en Regalos y en Overlays › Regalos y modos
    $('#modesCard').innerHTML = $('#ovModes').innerHTML = S.modes.map((m) => `<div class="set">
        <button class="gift" data-pick="${m.key}" style="width:96px">${m.img ? `<img src="${esc(m.img)}">` : '<div style="font-size:34px">🎁</div>'}${esc(m.gift || t('noGift'))}</button>
        <div style="flex:1"><label class="cap">${MODE_ICON[m.key]} ${t('mode_' + m.key)}</label>
          <input data-label="${m.key}" value="${esc(S.cfg.modes[m.key].label)}" placeholder="${esc(S.modeLabel[m.key])}" maxlength="40" style="width:100%">
          ${'seconds' in S.cfg.modes[m.key] ? `<div class="row" style="margin-top:6px"><input type="number" data-secs="${m.key}" min="3" max="${m.key === 'party' ? 300 : 60}" value="${S.cfg.modes[m.key].seconds}" style="width:90px"><span class="hint">${t('partySecs')}</span></div>` : ''}</div>
        <button class="toggle ${m.on ? 'on' : ''}" data-on="${m.key}"></button></div>`).join('');
    $('#tModes').innerHTML = S.modes.filter((m) => m.on && m.gift).map((m) =>
      `<button class="btn btn-ghost btn-sm jelly" data-tmode="${esc(m.gift)}" data-coins="${m.coins}">${m.img ? `<img src="${esc(m.img)}" style="width:20px;height:20px">` : MODE_ICON[m.key]} ${esc(m.label)}</button>`).join('');
  }
  // juego
  $('#afk').classList.toggle('on', !!S.cfg.afk);
  $('#scrWalker').classList.toggle('on', S.cfg.screen === 'walker');
  const sk = S.cfg.stage_style + L;
  if ($('#stStyles').dataset.k !== sk) {
    $('#stStyles').dataset.k = sk;
    $('#stStyles').innerHTML = STYLES.map((s) => `<button data-st="${s}" class="${s === S.cfg.stage_style ? 'on' : ''}">${t('style_' + s)}</button>`).join('');
  }
  for (const [id, list, key, attr, pre] of [['#stFloors', FLOORS, 'stage_floor', 'fl', 'floor_'], ['#stBarriers', BARRIERS, 'stage_barrier', 'ba', 'barrier_'], ['#stMarks', MARKS, 'stage_marks', 'mk', 'marks_'], ['#stNight', NIGHT, 'stage_night', 'ni', 'night_'], ['#stEvery', ROT_TIMES, 'rot_every', 're', 'every_']]) {
    const k = S.cfg[key] + L;
    if ($(id).dataset.k !== k) {
      $(id).dataset.k = k;
      $(id).innerHTML = list.map((s) => `<button data-${attr}="${s}" class="${s === S.cfg[key] ? 'on' : ''}">${t(pre + s)}</button>`).join('');
    }
  }
  const rk = S.cfg.rot_off.join() + L;
  if ($('#stRot').dataset.k !== rk) {
    $('#stRot').dataset.k = rk;
    $('#stRot').innerHTML = STYLES.map((s) => `<button data-ro="${s}" class="${S.cfg.rot_off.includes(s) ? '' : 'on'}">${S.cfg.rot_off.includes(s) ? '☐' : '☑'} ${t('style_' + s)}</button>`).join('');
  }
  for (const [id, k] of [['#afkMin', 'afk_minutes'], ['#walkGap', 'walk_gap'], ['#cineGap', 'cine_gap'], ['#adSite', 'site'], ['#fastOn', 'fast_on'], ['#fastOff', 'fast_off'], ['#fastX', 'fast_x']]) if (!typing($(id))) $(id).value = S.cfg[k];
  renderOverlays();
}

$('#queue').onclick = (e) => { const b = e.target.closest('[data-q]'); if (b) api('/api/queue', { action: b.dataset.q, name: b.dataset.n }).then(refresh); };
$('#qClear').onclick = () => api('/api/queue', { action: 'clear' }).then(refresh);
$('#paused').onclick = () => cfgSet({ paused: !S.cfg.paused });
$('#tModes').onclick = (e) => {
  const b = e.target.closest('[data-tmode]');
  if (b) api('/api/test', { kind: 'gift', nick: $('#tName').value.trim() || 'Wylo', gift: b.dataset.tmode, diamonds: Number(b.dataset.coins) || 1 }).then(refresh);
};
const modesClick = (e) => {
  const on = e.target.closest('[data-on]'), pick = e.target.closest('[data-pick]');
  if (on) cfgSet({ modes: { [on.dataset.on]: { on: !on.classList.contains('on') } } });
  if (pick) openGifts(pick.dataset.pick);
};
const modesChange = (e) => {
  if (e.target.dataset.label) cfgSet({ modes: { [e.target.dataset.label]: { label: e.target.value } } });
  if (e.target.dataset.secs) cfgSet({ modes: { [e.target.dataset.secs]: { seconds: Number(e.target.value) } } });
};

for (const id of ['#modesCard', '#ovModes']) { $(id).onclick = modesClick; $(id).onchange = modesChange; }

// elegir regalo de la lista de TikTok
let giftFor = null, giftList = null;
async function openGifts(key) {
  giftFor = key;
  $('#giftModal').classList.add('open');
  $('#gSearch').value = '';
  if (!giftList) { $('#gList').innerHTML = '<div class="hint">…</div>'; giftList = (await api('/api/gifts')).gifts || []; }
  drawGifts();
}
function drawGifts() {
  const q = $('#gSearch').value.trim().toLowerCase();
  $('#gList').innerHTML = giftList.filter((g) => !q || g.name.toLowerCase().includes(q))
    .map((g) => `<button class="gift" data-g="${esc(g.name)}"><img src="${esc(g.img)}" loading="lazy">${esc(g.name)}<br><small class="hint">🪙 ${g.coins}</small></button>`).join('');
}
$('#gSearch').oninput = drawGifts;
$('#gClose').onclick = () => $('#giftModal').classList.remove('open');
$('#gList').onclick = (e) => {
  const b = e.target.closest('[data-g]');
  if (!b) return;
  cfgSet({ modes: { [giftFor]: { gift: b.dataset.g } } });
  $('#giftModal').classList.remove('open');
};

// overlays: enlace, vista previa editable y lista de elementos
function ovUrl(v) { return `${S.overlayHost}/o/${v}`; }
function renderOverlays() {
  $('#ovViews').innerHTML = OV_VIEWS.map((v) => `<button data-ov="${v}" class="${v === ovView ? 'on' : ''}">${t('ov_' + v)}</button>`).join('');
  if (!typing($('#ovUrl'))) $('#ovUrl').value = ovUrl(ovView);
  const src = `/o/${ovView}?edit=1`;
  if ($('#ovFrame').getAttribute('src') !== src) $('#ovFrame').setAttribute('src', src);
  $('#ovModesWrap').hidden = ovView !== 'modes' && ovView !== 'all';
  const els = S.cfg.ov[ovView], key = ovView + JSON.stringify(els) + L;
  if (key === lastEls || $('#ovEls').contains(document.activeElement)) return;
  lastEls = key;
  $('#ovEls').innerHTML = Object.entries(els).map(([name, e]) => `<div class="set" data-el="${name}" style="flex-wrap:wrap">
      <button class="toggle ${e.show ? 'on' : ''}" data-f="show"></button>
      <b style="width:150px">${t('el_' + name)}</b>
      ${name === 'modes' || name === 'card' ? '' : `<input data-f="text" value="${esc(e.text)}" placeholder="${esc(S.ovText[name] || '')}" maxlength="120" style="flex:1;min-width:180px">`}
      <select data-f="font">${FONTS.map((f) => `<option ${f === e.font ? 'selected' : ''}>${f}</option>`).join('')}</select>
      <input type="color" data-f="color" value="${e.color}" title="color">
      ${e.accent ? `<input type="color" data-f="accent" value="${e.accent}" title="${t('accent')}">` : ''}
      <span class="hint">${t('size')}</span><input type="number" data-f="size" value="${e.size}" min="6" max="400" style="width:76px">
      ${e.every ? `<span class="hint">${t('every')}</span><input type="number" data-f="every" value="${e.every}" min="2" max="60" style="width:66px">` : ''}
      ${name === 'queue' ? `<span class="hint">${t('maxRows')}</span><input type="number" data-f="max" value="${e.max}" min="1" max="20" style="width:66px">` : ''}
    </div>`).join('');
}
const setEl = (name, field, value) => cfgSet({ ov: { [ovView]: { [name]: { [field]: value } } } });
$('#ovEls').onchange = (e) => {
  const f = e.target.dataset.f, row = e.target.closest('[data-el]');
  if (f && row) setEl(row.dataset.el, f, e.target.type === 'number' ? Number(e.target.value) : e.target.value);
};
$('#ovEls').onclick = (e) => {
  const tg = e.target.closest('[data-f="show"]');
  if (tg) setEl(tg.closest('[data-el]').dataset.el, 'show', !tg.classList.contains('on'));
};
$('#ovViews').onclick = (e) => { const b = e.target.closest('[data-ov]'); if (b) { ovView = b.dataset.ov; lastEls = ''; renderOverlays(); } };
$('#ovCopy').onclick = () => { navigator.clipboard.writeText(ovUrl(ovView)); toast(t('copied')); };
$('#ovReset').onclick = () => cfgSet({ ovReset: ovView }).then(() => (lastEls = ''));
// la vista previa (iframe 1080x1920, vertical) se escala al ancho disponible
new ResizeObserver(([e]) => $('#ovFrame').style.setProperty('--k', e.contentRect.width / 1080)).observe($('.ovstage'));

// juego
$('#afk').onclick = () => cfgSet({ afk: !S.cfg.afk });
$('#scrWalker').onclick = () => cfgSet({ screen: S.cfg.screen === 'walker' ? 'off' : 'walker' });
$('#afkMin').onchange = () => cfgSet({ afk_minutes: Number($('#afkMin').value) });
$('#walkGap').onchange = () => cfgSet({ walk_gap: Number($('#walkGap').value) });
$('#cineGap').onchange = () => cfgSet({ cine_gap: Number($('#cineGap').value) });
$('#fastOn').onchange = () => cfgSet({ fast_on: Number($('#fastOn').value) });
$('#fastOff').onchange = () => cfgSet({ fast_off: Number($('#fastOff').value) });
$('#fastX').onchange = () => cfgSet({ fast_x: Number($('#fastX').value) });
$('#afkTest').onclick = async () => { const r = await api('/api/test', { kind: 'afk' }); $('#afkMsg').textContent = t(r.ok ? 'afkOk' : 'afkNo'); };
$('#stGo').onclick = () => api('/api/stage', { text: $('#stText').value, color: $('#stColor').value });
$('#stAuto').onclick = () => api('/api/stage', { color: 'auto' });
const STYLES = ['minimal', 'museo', 'cine', 'espacio', 'pasarela', 'vegas', 'jardin', 'ciudad'];
const FLOORS = ['auto', 'blanco', 'negro', 'gris', 'crema', 'rosa', 'azul', 'verde'];
const BARRIERS = ['auto', 'metal', 'cuerda', 'evento', 'cristal', 'neon', 'seto', 'cinta', 'ninguna'];
const MARKS = ['si', 'no'];
const NIGHT = ['dia', 'noche'];
const ROT_TIMES = [0, 1, 2, 5, 10];
$('#stStyles').onclick = (e) => { const b = e.target.closest('[data-st]'); if (b) api('/api/stage', { style: b.dataset.st }).then(refresh); };
$('#stFloors').onclick = (e) => { const b = e.target.closest('[data-fl]'); if (b) api('/api/stage', { floor: b.dataset.fl }).then(refresh); };
$('#stBarriers').onclick = (e) => { const b = e.target.closest('[data-ba]'); if (b) api('/api/stage', { barrier: b.dataset.ba }).then(refresh); };
$('#stMarks').onclick = (e) => { const b = e.target.closest('[data-mk]'); if (b) api('/api/stage', { marks: b.dataset.mk }).then(refresh); };
$('#stNight').onclick = (e) => { const b = e.target.closest('[data-ni]'); if (b) api('/api/stage', { night: b.dataset.ni }).then(refresh); };
$('#stRot').onclick = (e) => { const b = e.target.closest('[data-ro]'); if (b) api('/api/stage', { rot_toggle: b.dataset.ro }).then(refresh); };
$('#stEvery').onclick = (e) => { const b = e.target.closest('[data-re]'); if (b) api('/api/stage', { rot_every: Number(b.dataset.re) }).then(refresh); };

refresh();
setInterval(refresh, 1000);
