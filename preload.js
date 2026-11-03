const { contextBridge, ipcRenderer: ipc } = require('electron');

contextBridge.exposeInMainWorld('api', {
  state: () => ipc.invoke('state'),
  create: (game, profile) => ipc.invoke('create', game, profile),
  run: (id) => ipc.invoke('run', id),
  open: (id) => ipc.invoke('open', id),
  active: (id) => ipc.invoke('active', id),
  close: (id, keep) => ipc.invoke('close', id, keep),
  profile: (id, d) => ipc.invoke('profile', id, d),
  remove: (id) => ipc.invoke('delete', id),
  saveTabs: (on) => ipc.invoke('saveTabs', on),
  on: (ch, fn) => ipc.on(ch, (_, d) => fn(d)),
});
