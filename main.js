// Coreus Games: abre los programas de los juegos de Roblox en pestañas dentro de la misma ventana.
// Cada pestaña es un .exe con COREUS_PORT y COREUS_DATA, y su panel web dentro de un <webview>.
const { app, BrowserWindow, dialog, ipcMain: ipc, shell } = require('electron');
const { spawn, execFile } = require('child_process');
const crypto = require('crypto');
const fs = require('fs');
const https = require('https');
const http = require('http');
const net = require('net');
const os = require('os');
const path = require('path');
const { GAMES, gameById, instanceDirName, stateInfo, nextName, setConfigUser, portPid } = require('./lib');

const ROOT = process.env.COREUS_HOME || path.join(os.homedir(), 'CoreusGames'); // fuera de AppData: las apps empaquetadas la redirigen
const PROGRAMS = path.join(ROOT, 'programs');
const INSTANCES = path.join(ROOT, 'instances');
const STORE = path.join(ROOT, 'launcher.json');
const MANIFEST = 'https://raw.githubusercontent.com/cristiancordova1207/Coreus-Games-Program-Releases/main/manifest.json';
const SEED = ['config.json', 'session.dat', 'cloud_key.txt']; // lo que hereda una instancia nueva: ajustes y sesión, no el historial

let win;
let db = { saveTabs: true, instances: [], active: null };
const running = new Map(); // id -> { proc, port, info }

function load() {
  fs.mkdirSync(ROOT, { recursive: true });
  try { db = { ...db, ...JSON.parse(fs.readFileSync(STORE, 'utf8')) }; } catch {}
}
function save() {
  const t = STORE + '.tmp';
  fs.writeFileSync(t, JSON.stringify(db, null, 1));
  fs.renameSync(t, STORE); // nunca se queda a medias
}
const send = (ch, d) => { if (win && !win.isDestroyed()) win.webContents.send(ch, d); };
const inst = (id) => db.instances.find((i) => i.id === id);

function portFree(port) {
  return new Promise((res) => {
    const s = net.createServer();
    s.once('error', () => res(false));
    s.listen(port, '127.0.0.1', () => s.close(() => res(true)));
  });
}
async function freePort(from) {
  const taken = new Set([...running.values()].map((r) => r.port));
  for (let p = from; p < from + 200; p++) if (!taken.has(p) && await portFree(p)) return p;
  throw new Error('no_port');
}
function get(url, redirects = 5) {
  return new Promise((res, rej) => {
    const lib = url.startsWith('https') ? https : http;
    const r = lib.get(url, { headers: { 'User-Agent': 'CoreusGames' }, timeout: 15000 }, (m) => {
      if ([301, 302, 307, 308].includes(m.statusCode) && m.headers.location && redirects) { m.resume(); return res(get(m.headers.location, redirects - 1)); }
      if (m.statusCode !== 200) { m.resume(); return rej(new Error('http_' + m.statusCode)); }
      res(m);
    });
    r.on('timeout', () => r.destroy(new Error('timeout')));
    r.on('error', rej);
  });
}
async function getJson(url) {
  const m = await get(url);
  let s = '';
  for await (const c of m) s += c;
  return JSON.parse(s);
}

// ---------- los programas: se bajan al abrirlos por primera vez y al salir versión nueva ----------
const localExes = (game) => { try { return fs.readdirSync(PROGRAMS).filter((f) => f.startsWith(game + '-') && f.endsWith('.exe')); } catch { return []; } };
const downloading = new Map();
async function download(game, g, target) {
  fs.mkdirSync(PROGRAMS, { recursive: true });
  const tmp = target + '.part';
  const m = await get(g.url);
  const total = Number(m.headers['content-length']) || g.size || 0;
  const hash = crypto.createHash('sha256');
  const out = fs.createWriteStream(tmp);
  let done = 0, last = 0;
  for await (const c of m) {
    hash.update(c);
    done += c.length;
    if (!out.write(c)) await new Promise((r) => out.once('drain', r));
    if (Date.now() - last > 250) { last = Date.now(); send('download', { game, done, total }); }
  }
  await new Promise((r) => out.end(r));
  if (g.sha256 && hash.digest('hex') !== g.sha256) { fs.rmSync(tmp, { force: true }); throw new Error('bad_download'); }
  fs.renameSync(tmp, target);
  for (const old of localExes(game)) { // la versión anterior, si no está abierta
    if (path.join(PROGRAMS, old) !== target) fs.rm(path.join(PROGRAMS, old), { force: true }, () => {});
  }
  send('download', { game, done: total, total, finished: true });
}
async function ensureExe(game) {
  if (process.env.COREUS_LOCAL_EXES) return path.join(process.env.COREUS_LOCAL_EXES, game + '.exe'); // pruebas
  let g = null;
  try { g = (await getJson(MANIFEST + '?t=' + Math.floor(Date.now() / 300000))).games[game]; } catch {}
  const have = localExes(game);
  if (!g) { // sin internet: con lo que haya
    if (have.length) return path.join(PROGRAMS, have.sort().pop());
    throw new Error('offline');
  }
  const target = path.join(PROGRAMS, `${game}-${g.version}.exe`);
  if (fs.existsSync(target)) return target;
  if (!downloading.has(game)) downloading.set(game, download(game, g, target).finally(() => downloading.delete(game)));
  await downloading.get(game);
  return target;
}

// ---------- instancias ----------
function seedData(i, g) {
  const dir = path.join(INSTANCES, instanceDirName(i.id));
  fs.mkdirSync(dir, { recursive: true });
  if (!fs.existsSync(path.join(dir, 'config.json'))) {
    for (const f of SEED) { try { fs.copyFileSync(path.join(g.dataDir(), f), path.join(dir, f)); } catch {} }
    if (!i.tiktok) setConfigUser(path.join(dir, 'config.json'), ''); // cada instancia con su cuenta de TikTok
  }
  return dir;
}
function waitReady(port, proc) {
  return new Promise((res, rej) => {
    const t0 = Date.now();
    const tick = () => {
      if (proc.exitCode !== null) return rej(new Error('exited'));
      if (Date.now() - t0 > 90000) return rej(new Error('timeout'));
      const r = http.get({ host: '127.0.0.1', port, path: '/api/state', timeout: 1500 }, (m) => { m.resume(); m.statusCode < 500 ? res() : setTimeout(tick, 500); });
      r.on('timeout', () => r.destroy());
      r.on('error', () => setTimeout(tick, 500));
    };
    tick();
  });
}
function kill(pid) {
  return new Promise((res) => execFile('taskkill', ['/PID', String(pid), '/T', '/F'], { windowsHide: true }, () => res()));
}
// El puerto de siempre está ocupado por algo que no es de Coreus, normalmente el programa abierto por su acceso directo.
// Sin preguntar saldría una copia sin ranking ni jugadores mientras el otro sigue mandando al juego. true = usar el puerto de siempre.
async function resolveBusyPort(g) {
  const state = await getJson(`http://127.0.0.1:${g.port}/api/state`).catch(() => null);
  const info = state && stateInfo(state);
  const onAir = !!info && (info.live || info.connecting);
  const pid = state && !onAir ? await new Promise((res) => execFile('netstat', ['-ano', '-p', 'TCP'], { windowsHide: true }, (e, out) => res(e ? null : portPid(out, g.port)))) : null;
  const buttons = [...(pid ? ['Cerrarlo y abrirlo aquí'] : []), 'Abrir una copia aparte', 'Cancelar'];
  const message = !state ? `Otra aplicación está usando el puerto ${g.port}, el que necesita ${g.name}.`
    : onAir ? `${g.name} está abierto fuera de Coreus y en directo.`
    : `${g.name} ya está abierto fuera de Coreus.`;
  const copy = 'Una copia aparte empieza sin tu ranking ni tus jugadores y no usa las URLs de tus overlays.';
  const detail = !state ? copy
    : onAir ? `No se puede cerrar desde aquí mientras dure el directo. ${copy}`
    : `Ese programa sigue mandando personajes a tu juego, así que lo que hagas en otra pestaña puede no llegar. ${copy}`;
  const opts = { type: 'warning', title: 'Coreus Games', message, detail, buttons, defaultId: pid ? 0 : buttons.length - 1, cancelId: buttons.length - 1, noLink: true };
  const answer = process.env.COREUS_DIALOG ? Number(process.env.COREUS_DIALOG) // pruebas: el botón que se pulsaría
    : (await dialog.showMessageBox(win, opts)).response;
  if (buttons[answer] === 'Cancelar') throw new Error('cancelled');
  if (buttons[answer] !== 'Cerrarlo y abrirlo aquí') return false;
  await kill(pid);
  for (let t = 0; t < 20; t++) {
    if (await portFree(g.port)) return true;
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error('port_busy');
}
const starts = new Map();
function start(i) {
  if (running.has(i.id)) return Promise.resolve(running.get(i.id));
  if (!starts.has(i.id)) starts.set(i.id, doStart(i).finally(() => starts.delete(i.id)));
  return starts.get(i.id);
}
async function doStart(i) {
  const g = gameById(i.game);
  const exe = await ensureExe(i.game);
  // La primera instancia usa el puerto y los datos de siempre (overlays y ajustes intactos). Las demás, los suyos.
  let useDefault = !i.own && ![...running.keys()].some((id) => { const o = inst(id); return o && o.game === i.game && !o.own; });
  if (useDefault && !await portFree(g.port)) useDefault = await resolveBusyPort(g);
  let port;
  if (useDefault) port = g.port;
  else {
    i.own = true;
    port = await freePort(i.port && i.port !== g.port ? i.port : g.port + 1000); // +1 chocaría con otro juego (5092, 5093...)
  }
  i.port = port;
  save();
  const env = { ...process.env, COREUS_PORT: String(port), PYINSTALLER_RESET_ENVIRONMENT: '1' };
  delete env.ELECTRON_RUN_AS_NODE;
  if (i.own) env.COREUS_DATA = seedData(i, g);
  const dataDir = i.own ? env.COREUS_DATA : g.dataDir();
  if (i.tiktok) setConfigUser(path.join(dataDir, 'config.json'), i.tiktok);
  const proc = spawn(exe, ['--no-window'], { env, windowsHide: true, stdio: 'ignore' });
  const r = { proc, port, info: {} };
  running.set(i.id, r);
  proc.on('error', () => {});
  proc.on('exit', () => {
    if (running.get(i.id) === r) { running.delete(i.id); send('exit', i.id); }
  });
  try {
    await waitReady(port, proc);
  } catch (e) {
    running.delete(i.id);
    await kill(proc.pid);
    throw e;
  }
  return r;
}
async function stop(id) {
  const r = running.get(id);
  if (!r) return;
  running.delete(id);
  await kill(r.proc.pid);
}
function poll() {
  for (const [id, r] of running) {
    const q = http.get({ host: '127.0.0.1', port: r.port, path: '/api/state', timeout: 1500 }, (m) => {
      let s = '';
      m.setEncoding('utf8');
      m.on('data', (c) => { s += c; });
      m.on('end', () => {
        try {
          r.info = stateInfo(JSON.parse(s));
          const i = inst(id);
          if (i && r.info.tiktok && i.lastTiktok !== r.info.tiktok) { i.lastTiktok = r.info.tiktok; save(); }
        } catch {}
      });
    });
    q.on('timeout', () => q.destroy());
    q.on('error', () => {});
  }
  send('status', Object.fromEntries([...running].map(([id, r]) => [id, { port: r.port, ...r.info }])));
}

const view = () => ({ games: GAMES.map(({ dataDir, ...g }) => g), ...db });

ipc.handle('state', () => view());
ipc.handle('create', (_, game, profile) => { // pestaña nueva, o perfil guardado sin abrir
  gameById(game);
  const i = { id: crypto.randomUUID().slice(0, 8), game, name: nextName(gameById(game).name, db.instances.filter((x) => x.game === game)),
    profile: !!profile, open: !profile, tiktok: '', own: !!profile };
  db.instances.push(i);
  if (!profile) db.active = i.id;
  save();
  return view();
});
ipc.handle('run', async (_, id) => { // arranca el programa de una pestaña y devuelve su panel
  const i = inst(id);
  if (!i) return { error: 'gone' };
  try {
    const r = await start(i);
    return { url: `http://127.0.0.1:${r.port}${gameById(i.game).panel || '/'}`, port: r.port };
  } catch (e) {
    return { error: e.message };
  }
});
ipc.handle('open', (_, id) => {
  const i = inst(id);
  if (i) { i.open = true; db.active = id; save(); }
  return view();
});
ipc.handle('active', (_, id) => { db.active = id; save(); });
ipc.handle('close', async (_, id, keep) => { // cierra la pestaña. keep = lo que hacer con una instancia extra sin perfil
  const i = inst(id);
  if (!i) return view();
  await stop(id);
  i.open = false;
  if (db.active === id) db.active = null;
  if (keep === 'profile') i.profile = true;
  if (!i.profile) {
    db.instances = db.instances.filter((x) => x !== i);
    if (i.own) fs.rm(path.join(INSTANCES, instanceDirName(i.id)), { recursive: true, force: true }, () => {});
  }
  save();
  return view();
});
ipc.handle('profile', async (_, id, d) => { // guardar o editar un perfil
  const i = inst(id);
  if (!i) return view();
  if (d.name !== undefined) i.name = String(d.name).trim().slice(0, 40) || i.name;
  if (d.tiktok !== undefined) i.tiktok = String(d.tiktok).trim().replace(/^@/, '').toLowerCase().slice(0, 24);
  if (d.profile !== undefined) i.profile = !!d.profile;
  save();
  return view();
});
ipc.handle('delete', async (_, id) => {
  const i = inst(id);
  if (!i) return view();
  await stop(id);
  db.instances = db.instances.filter((x) => x !== i);
  if (i.own) fs.rm(path.join(INSTANCES, instanceDirName(i.id)), { recursive: true, force: true }, () => {});
  save();
  return view();
});
ipc.handle('saveTabs', (_, on) => { db.saveTabs = !!on; save(); return view(); });

const gotLock = app.requestSingleInstanceLock();
if (!gotLock) app.quit();
app.on('second-instance', () => { if (win) { if (win.isMinimized()) win.restore(); win.focus(); } });

app.on('web-contents-created', (_, wc) => {
  // lo que un panel abre con window.open va al navegador
  wc.setWindowOpenHandler(({ url }) => {
    if (/^https?:/.test(url)) shell.openExternal(url);
    return { action: 'deny' };
  });
});
app.whenReady().then(() => {
  load();
  win = new BrowserWindow({
    width: 1320, height: 860, minWidth: 900, minHeight: 600, backgroundColor: '#121016', title: 'Coreus Games', autoHideMenuBar: true,
    icon: path.join(__dirname, 'assets', 'icon.png'),
    show: !process.env.COREUS_HOME, // en pruebas, sin quitar el foco a lo que esté abierto
    webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, webviewTag: true },
  });
  win.setMenuBarVisibility(false);
  if (process.env.COREUS_HOME) win.showInactive();
  win.loadFile(path.join(__dirname, 'ui', 'index.html'));
  setInterval(poll, 2000);
});
let quitting = false;
app.on('before-quit', (e) => {
  if (quitting) return;
  quitting = true;
  e.preventDefault();
  if (!db.saveTabs) {
    db.instances = db.instances.filter((i) => {
      i.open = false;
      if (i.profile) return true;
      if (i.own) fs.rmSync(path.join(INSTANCES, instanceDirName(i.id)), { recursive: true, force: true });
      return false;
    });
  }
  save();
  Promise.all([...running.keys()].map((id) => stop(id))).finally(() => app.exit(0));
});
app.on('window-all-closed', () => app.quit());
