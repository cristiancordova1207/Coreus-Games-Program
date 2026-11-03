const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { gameById, instanceDirName, stateInfo, nextName, setConfigUser } = require('./lib');

assert.throws(() => gameById('x'));
assert.equal(gameById('aura').port, 5091);
assert.throws(() => instanceDirName('..\\..\\Windows'));
assert.equal(instanceDirName('ab12cd34'), 'ab12cd34');
assert.equal(nextName('Aura', []), 'Aura');
assert.equal(nextName('Aura', [{ name: 'Aura' }, { name: 'Aura 2' }]), 'Aura 3');
assert.deepEqual(stateInfo({ status: 'live', tiktok: 'ana', cfg: { tiktok_user: 'vieja' } }).tiktok, 'ana');
assert.equal(stateInfo({ cfg: { tiktok_user: 'vieja' } }).tiktok, 'vieja');
assert.equal(stateInfo({}).live, false);

const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'coreus'));
const f = path.join(dir, 'a', 'config.json');
setConfigUser(f, 'ana');
fs.writeFileSync(f, JSON.stringify({ theme: 'x', tiktok_user: 'ana' }));
setConfigUser(f, 'beto');
assert.deepEqual(JSON.parse(fs.readFileSync(f, 'utf8')), { theme: 'x', tiktok_user: 'beto' }); // no pisa los demás ajustes
fs.rmSync(dir, { recursive: true });
console.log('ok');
