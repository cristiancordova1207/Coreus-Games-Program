// Coreus Games · pestañas, juegos y perfiles
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const ERR = { offline: 'Sin internet y el programa aún no está descargado.', timeout: 'El programa tarda demasiado en abrir.', exited: 'El programa se cerró al abrir.', bad_download: 'La descarga llegó dañada. Vuelve a intentarlo.', no_port: 'No hay puertos libres.' };

let S = null;
let status = {};
const views = new Map(); // id de pestaña -> { el, webview, port }; las de "Juego" de Snake son `<id>:extra`
const extras = new Set();
let current = null; // id de pestaña activa; null = inicio

const game = (id) => S.games.find((g) => g.id === id);
const openTabs = () => S.instances.filter((i) => i.open);

function toast(t) {
  const el = $('#toast');
  el.textContent = t;
  el.hidden = false;
  clearTimeout(toast.t);
  toast.t = setTimeout(() => { el.hidden = true; }, 3000);
}
function tabLabel(i) {
  const st = status[i.id] || {};
  const who = st.tiktok || i.tiktok || i.lastTiktok;
  return { sub: who ? '@' + who : st.account || 'sin conectar', title: [i.name, who && '@' + who, st.account && 'cuenta ' + st.account, st.roblox && 'Roblox ' + st.roblox, st.port && 'puerto ' + st.port].filter(Boolean).join(' · ') };
}
function renderTabs() {
  const box = $('#tabs');
  const html = [];
  for (const i of openTabs()) {
    const g = game(i.game), st = status[i.id] || {}, l = tabLabel(i);
    html.push(`<div class="tab ${current === i.id ? 'on' : ''}" data-tab="${i.id}" title="${esc(l.title)}" role="button">
      <span>${g.icon}</span><span class="dot ${st.live ? 'live' : st.connecting ? 'wait' : ''}"></span>
      <span class="txt"><b>${esc(i.name)}</b><small>${esc(l.sub)}</small></span>
      ${g.extra && !extras.has(i.id) ? `<button class="x" data-extra="${i.id}" title="Abrir ${esc(g.extra.label)}">${g.extra.icon}</button>` : ''}
      ${i.profile ? '' : `<button class="x" data-keep="${i.id}" title="Guardar como perfil">☆</button>`}
      <button class="x" data-close="${i.id}" title="Cerrar pestaña">✕</button></div>`);
    if (extras.has(i.id)) {
      const k = i.id + ':extra';
      html.push(`<div class="tab ${current === k ? 'on' : ''}" data-tab="${k}" role="button"><span>${g.extra.icon}</span>
        <span class="txt"><b>${esc(g.extra.label)}</b><small>${esc(i.name)}</small></span>
        <button class="x" data-closex="${i.id}" title="Cerrar">✕</button></div>`);
    }
  }
  box.innerHTML = html.join('');
  $('#homeTab').classList.toggle('on', current === null);
}
function renderHome() {
  $('#games').innerHTML = S.games.map((g, n) => {
    const count = openTabs().filter((i) => i.game === g.id).length;
    return `<div class="game" style="animation-delay:${n * 45}ms"><div class="ico">${g.icon}</div><b>${esc(g.name)}</b>
      <p>${count ? `${count} abierto${count > 1 ? 's' : ''}` : 'Sin abrir'}</p>
      <div class="acts"><button class="btn main" data-launch="${g.id}">Launch</button>
      <button class="btn ghost" data-newprof="${g.id}" title="Nuevo perfil">＋</button></div></div>`;
  }).join('');
  const profs = S.instances.filter((i) => i.profile);
  $('#profiles').innerHTML = profs.length ? profs.map((i) => {
    const g = game(i.game);
    return `<div class="prof"><span class="ico">${g.icon}</span><div class="grow"><b>${esc(i.name)}</b>
      <p>${esc(g.name)}${i.tiktok ? ' · @' + esc(i.tiktok) : ''}${i.open ? ' · abierto' : ''}</p></div>
      <button class="btn main" style="flex:none" data-prof="${i.id}">Abrir</button>
      <button class="btn ghost" data-edit="${i.id}">Editar</button>
      <button class="btn ghost danger" data-del="${i.id}">Borrar</button></div>`;
  }).join('') : '<div class="empty">Pulsa ＋ en un juego para guardar uno.</div>';
  $('#saveTabs').classList.toggle('on', S.saveTabs);
}
function select(id) {
  current = id;
  $('#home').hidden = id !== null;
  for (const [k, v] of views) v.el.classList.toggle('on', k === id);
  if (id && !id.includes(':')) window.api.active(id);
  else if (id === null) window.api.active(null);
  renderTabs();
}
function message(el, html) {
  let m = el.querySelector('.msg');
  if (!m) { m = document.createElement('div'); m.className = 'msg'; el.append(m); }
  m.innerHTML = html;
  m.hidden = !html;
  m.style.display = html ? '' : 'none';
}
async function mountTab(i) {
  if (views.has(i.id)) return;
  const el = document.createElement('div');
  el.className = 'view';
  el.dataset.game = i.game;
  $('#views').append(el);
  const v = { el };
  views.set(i.id, v);
  await boot(i, v);
}
async function boot(i, v) {
  v.webview?.remove();
  v.webview = null;
  message(v.el, `<div class="loader"><i></i><i></i><i></i><i></i></div><div class="what">Abriendo ${esc(game(i.game).name)}…</div><div class="bar" hidden><i></i></div>`);
  const r = await window.api.run(i.id);
  if (!views.has(i.id)) return; // se cerró mientras abría
  if (r.error) {
    message(v.el, `<div>⚠️ ${esc(ERR[r.error] || r.error)}</div><button class="btn ghost" data-retry="${i.id}">Reintentar</button>`);
    return;
  }
  v.port = r.port;
  v.webview = document.createElement('webview');
  v.webview.src = r.url;
  v.webview.setAttribute('allowpopups', '');
  v.el.append(v.webview);
  message(v.el, '');
  renderTabs();
}
function mountExtra(i) {
  const k = i.id + ':extra', base = views.get(i.id);
  if (views.has(k) || !base?.port) return;
  const el = document.createElement('div');
  el.className = 'view';
  const w = document.createElement('webview');
  w.src = `http://127.0.0.1:${base.port}${game(i.game).extra.path}`;
  el.append(w);
  $('#views').append(el);
  views.set(k, { el, webview: w });
  extras.add(i.id);
}
function unmount(k) {
  views.get(k)?.el.remove();
  views.delete(k);
}
function dropExtra(id) {
  unmount(id + ':extra');
  extras.delete(id);
}

// ---------- diálogos ----------
function ask(html) {
  const d = $('#dlg');
  $('#dlgForm').innerHTML = html;
  d.showModal();
  return new Promise((res) => d.addEventListener('close', () => res(d.returnValue), { once: true }));
}
async function editProfile(id) {
  const i = S.instances.find((x) => x.id === id);
  const ans = await ask(`<h2>${game(i.game).icon} Perfil de ${esc(game(i.game).name)}</h2>
    <p>Los regalos, la cuenta y el resto se cambian en su panel al abrirlo; se quedan guardados en este perfil.</p>
    <label>Nombre<input id="pName" maxlength="40" value="${esc(i.name)}"></label>
    <label>Usuario de TikTok<input id="pTik" maxlength="25" placeholder="@usuario" value="${esc(i.tiktok || '')}" spellcheck="false"></label>
    <div class="acts"><button class="btn ghost" value="no">Cancelar</button><button class="btn main" value="ok">Guardar</button></div>`);
  if (ans !== 'ok') return false;
  S = await window.api.profile(id, { name: $('#pName').value, tiktok: $('#pTik').value, profile: true });
  sync();
  return true;
}
async function closeTab(id) {
  const i = S.instances.find((x) => x.id === id);
  let keep = '';
  if (i.own && !i.profile) {
    const ans = await ask(`<h2>¿Guardar esta instancia?</h2><p>${esc(i.name)} tiene sus propios ajustes. Si no la guardas como perfil, se borran.</p>
      <div class="acts"><button class="btn ghost" value="cancel">Cancelar</button><button class="btn ghost danger" value="del">Borrar</button><button class="btn main" value="profile">Guardar perfil</button></div>`);
    if (ans === 'cancel' || !ans) return;
    keep = ans === 'profile' ? 'profile' : '';
  }
  dropExtra(id);
  unmount(id);
  if (current === id || current === id + ':extra') select(null);
  S = await window.api.close(id, keep);
  sync();
}

function sync() {
  renderTabs();
  renderHome();
}

// ---------- clics ----------
document.addEventListener('click', async (e) => {
  const t = e.target.closest('button, .tab');
  if (!t) return;
  const d = t.dataset;
  if (t.closest('dialog')) return;
  if (d.close) return closeTab(d.close);
  if (d.keep) return editProfile(d.keep);
  if (d.closex) { dropExtra(d.closex); if (current === d.closex + ':extra') select(d.closex); renderTabs(); return; }
  if (d.extra) { const i = S.instances.find((x) => x.id === d.extra); mountExtra(i); select(d.extra + ':extra'); return; }
  if (d.tab) return select(d.tab);
  if (d.launch) {
    const known = new Set(S.instances.map((x) => x.id));
    S = await window.api.create(d.launch, false);
    const i = S.instances.find((x) => !known.has(x.id));
    sync();
    mountTab(i);
    select(i.id);
    return;
  }
  if (d.newprof) {
    const known = new Set(S.instances.map((x) => x.id));
    S = await window.api.create(d.newprof, true);
    const i = S.instances.find((x) => !known.has(x.id));
    if (!await editProfile(i.id)) { S = await window.api.remove(i.id); sync(); }
    return;
  }
  if (d.prof) {
    S = await window.api.open(d.prof);
    sync();
    mountTab(S.instances.find((x) => x.id === d.prof));
    select(d.prof);
    return;
  }
  if (d.edit) return editProfile(d.edit);
  if (d.del) {
    const i = S.instances.find((x) => x.id === d.del);
    const ans = await ask(`<h2>¿Borrar ${esc(i.name)}?</h2><p>Se borran sus ajustes guardados.</p><div class="acts"><button class="btn ghost" value="no">Cancelar</button><button class="btn main" value="ok">Borrar</button></div>`);
    if (ans !== 'ok') return;
    dropExtra(d.del);
    unmount(d.del);
    if (current === d.del) select(null);
    S = await window.api.remove(d.del);
    sync();
    return;
  }
  if (d.retry) { const i = S.instances.find((x) => x.id === d.retry); boot(i, views.get(i.id)); return; }
});
$('#homeTab').onclick = () => select(null);
$('#saveTabs').onclick = async () => { S = await window.api.saveTabs(!S.saveTabs); sync(); };

// tema
function setTheme(t) {
  document.documentElement.dataset.theme = t;
  document.querySelectorAll('#themes button').forEach((b) => b.classList.toggle('on', b.dataset.t === t));
  try { localStorage.setItem('theme', t); } catch {}
}
$('#themes').onclick = (e) => { const b = e.target.closest('button'); if (b) setTheme(b.dataset.t); };
let saved = 'cozy-night';
try { saved = localStorage.getItem('theme') || saved; } catch {}
setTheme(saved);

// ---------- del proceso principal ----------
window.api.on('status', (st) => { status = st; renderTabs(); });
window.api.on('exit', (id) => {
  const v = views.get(id);
  const i = S.instances.find((x) => x.id === id);
  if (!v || !i) return;
  v.webview?.remove();
  v.webview = null;
  dropExtra(id);
  message(v.el, `<div>El programa se cerró.</div><button class="btn ghost" data-retry="${id}">Volver a abrir</button>`);
});
window.api.on('download', (d) => {
  for (const [k, v] of views) {
    if (v.el.dataset.game !== d.game) continue;
    const bar = v.el.querySelector('.bar'), what = v.el.querySelector('.what');
    if (!bar) continue;
    bar.hidden = !!d.finished;
    if (what) what.textContent = d.finished ? 'Abriendo…' : `Descargando… ${(d.done / 1e6).toFixed(0)} MB`;
    bar.firstElementChild.style.width = d.total ? (100 * d.done / d.total) + '%' : '30%';
  }
});

(async () => {
  S = await window.api.state();
  sync();
  const tabs = S.saveTabs ? openTabs() : [];
  for (const i of tabs) mountTab(i); // vuelven las pestañas de la última vez
  const active = tabs.find((i) => i.id === S.active);
  select(active ? active.id : null);
})();
