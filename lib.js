// Lo que no depende de Electron (lo prueba test_lib.js).
const fs = require('fs');
const os = require('os');
const path = require('path');

const appData = () => process.env.APPDATA || path.join(os.homedir(), 'AppData', 'Roaming');
const GAMES = [
  { id: 'snake', name: 'Snake Tik', icon: '🐍', port: 5010, dataDir: () => path.join(appData(), 'SnakeTik'), extra: { label: 'Juego', icon: '🎮', path: '/game' } },
  { id: 'dance', name: 'Roblox Dance', icon: '💃', port: 5077, dataDir: () => path.join(appData(), 'RobloxDance') },
  { id: 'fashion', name: 'Fashion Show', icon: '👗', port: 5088, dataDir: () => path.join(appData(), 'RobloxFashionShow') },
  { id: 'aura', name: 'Aura Farm', icon: '✨', port: 5091, dataDir: () => path.join(os.homedir(), 'AuraFarmRoblox') },
  { id: 'redcarpet', name: 'Red Carpet', icon: '🎬', port: 5093, dataDir: () => path.join(os.homedir(), 'RedCarpet') },
];
function gameById(id) {
  const g = GAMES.find((x) => x.id === id);
  if (!g) throw new Error('unknown_game');
  return g;
}
// el id viene de nuestro propio launcher.json, pero acaba en un borrado de carpeta
function instanceDirName(id) {
  if (!/^[0-9a-f-]{4,40}$/.test(String(id))) throw new Error('bad_id');
  return id;
}
// /api/state de cada programa -> lo que enseña la pestaña
function stateInfo(j) {
  const p = (j.account && j.account.profile) || {};
  const cfg = j.cfg || {};
  return {
    live: j.status === 'live',
    connecting: j.status === 'connecting',
    tiktok: j.tiktok || cfg.tiktok_user || '',
    account: p.username && p.username !== 'Red Carpet' ? p.username : '',
    roblox: cfg.roblox_user || p.robloxUser || '',
  };
}
function nextName(base, same) {
  if (!same.length) return base;
  const used = new Set(same.map((x) => x.name));
  for (let n = 2; ; n++) if (!used.has(`${base} ${n}`)) return `${base} ${n}`;
}
function setConfigUser(file, user) {
  let c = {};
  try { c = JSON.parse(fs.readFileSync(file, 'utf8')); } catch {}
  if (c.tiktok_user === user) return;
  c.tiktok_user = user;
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const t = file + '.tmp';
  fs.writeFileSync(t, JSON.stringify(c, null, 2));
  fs.renameSync(t, file);
}
module.exports = { GAMES, gameById, instanceDirName, stateInfo, nextName, setConfigUser };
