"""Red Carpet - la gente de tu LIVE de TikTok camina por la alfombra roja en Roblox.

Panel:     http://127.0.0.1:5093/
Overlays:  http://carpet.localtest.me:5093/o/all (todo junto) | title | lobby | now | queue | modes | donors  (TikTok LIVE Studio no acepta 127.0.0.1)
El programa es el cerebro: lleva la cola (saltar cola, prioridad, cinemático), los regalos, la fama y los overlays. El juego sólo dibuja:
  {k:w,n,u,c,h,v,fs,fg} camina · {k:g} gigante · {k:y} flota · {k:f} sesión de fotos · {k:p,s} fiesta · {k:t,text,color,style} pantalla y escenario
- Juego publicado: se publica directo por Open Cloud (MessagingService) en rc_<UserId> o rc_c<código>, con tu clave. Sin cuentas.
- Roblox Studio (▶ Jugar): el juego lee http://127.0.0.1:5093/api/poll directamente.
- Coreus Games lo abre con COREUS_PORT y COREUS_DATA para tener varias instancias.
"""
import asyncio
import copy
import ctypes
import ctypes.wintypes as wt
import http.client
import json
import os
import random
import re
import secrets
import shutil
import subprocess
import sys
import threading
import time
import urllib.request
import webbrowser
from collections import deque
from datetime import datetime

from flask import Flask, jsonify, request, send_from_directory

from TikTokLive import TikTokLiveClient
from TikTokLive.events import (CommentEvent, ConnectEvent, DisconnectEvent, FollowEvent, GiftEvent, LikeEvent, LiveEndEvent,
                               NoticeEvent, RoomUserSeqEvent, RoomVerifyEvent, ShareEvent)

import studio

from account import Account
from bots import BOTS

VERSION = "1.0.3"
PORT = int(os.environ.get("COREUS_PORT") or 5093)
OVERLAY_HOST = f"http://carpet.localtest.me:{PORT}"
UNIVERSE = 10774491686

BASE = getattr(sys, "_MEIPASS", os.path.dirname(os.path.abspath(__file__)))
UI_DIR = os.path.join(BASE, "ui")
# fuera de AppData: Claude Desktop (MSIX) redirige AppData a los procesos que lanza y parecería otro PC
CFG_DIR = os.environ.get("COREUS_DATA") or os.path.join(os.path.expanduser("~"), "RedCarpet")
KEY_PATH = os.path.join(CFG_DIR, "cloud_key.txt")  # clave de Roblox: aparte de config.json porque /api/state enseña cfg
FAME_PATH = os.path.join(CFG_DIR, "fame.json")
CFG_PATH = os.path.join(CFG_DIR, "config.json")
FROZEN = getattr(sys, "frozen", False)


def el(text, font, color, size, x, y, show=True):
    """Un elemento de overlay: x/y en % de la pantalla (centro), size en px."""
    return {"text": text, "font": font, "color": color, "size": size, "x": x, "y": y, "show": show}


# Lienzo vertical 1080x1920 (9:16, como el directo del vídeo de referencia); x/y en %.
OV_VERSION = 4  # súbelo cuando cambie el diseño por defecto de los overlays: las configs viejas se restablecen
TIMES_VERSION = 5  # ídem para walk_gap/cine_gap (dependen del recorrido del juego)
MODES_VERSION = 1  # regalos por defecto nuevos (gigante = corazón de 100, Universe Dance = Money Gun) y aprendizaje encendido
# Un overlay por sección (cada uno es una fuente «Enlace» en TikTok LIVE Studio). Texto "" = el del idioma del programa.
DEFAULT_OV = {
    # todo en uno (como el primero): cada parte se puede quitar con su interruptor y mover por separado
    "all": {
        "title": el("", "Lilita One", "#ffffff", 68, 50, 5),
        "subtitle": el("", "Lilita One", "#ffffff", 34, 50, 8.4),
        "lobby": el("", "Lilita One", "#ffffff", 34, 17, 13),
        "queue": el("", "Fredoka", "#ffffff", 28, 17, 16) | {"max": 5},
        "modes": el("", "Lilita One", "#ffffff", 32, 84, 17),
        "card": el("", "Fredoka", "#ffffff", 100, 50, 62) | {"accent": "#2ee6d6", "every": 5, "max": 20},
        "now": el("", "Lilita One", "#25f4ee", 44, 50, 74),
    },
    "title": {
        "title": el("", "Lilita One", "#ffffff", 68, 50, 42),
        "subtitle": el("", "Lilita One", "#ffffff", 34, 50, 58),
    },
    "lobby": {"lobby": el("", "Lilita One", "#ffffff", 40, 50, 50)},
    "now": {"now": el("", "Lilita One", "#25f4ee", 44, 50, 50)},
    "queue": {"queue": el("", "Fredoka", "#ffffff", 32, 50, 20) | {"max": 5}},
    "modes": {"modes": el("", "Lilita One", "#ffffff", 40, 50, 50)},
    "donors": {
        "card": el("", "Fredoka", "#ffffff", 100, 50, 50) | {"accent": "#2ee6d6", "every": 5, "max": 20},
    },
    # animación de cada regalo (uno detrás de otro): every = segundos que se ve cada uno
    "alerts": {"alert": el("", "Lilita One", "#ffffff", 100, 50, 45) | {"accent": "#fe2c55", "every": 4}},
}
OV_TEXT = {  # textos por defecto de los overlays según el idioma
    "es": {"title": "RED CARPET", "subtitle": "escribe tu usuario de Roblox para salir en la alfombra", "lobby": "EN COLA: {n}",
           "now": "EN LA ALFOMBRA: {name}", "queue": "SIGUIENTES", "alert": "{name} envió {gift} x{n}"},
    "en": {"title": "RED CARPET", "subtitle": "type your Roblox username to walk the carpet", "lobby": "IN LINE: {n}",
           "now": "ON THE CARPET: {name}", "queue": "NEXT UP", "alert": "{name} sent {gift} x{n}"},
}
MODE_LABEL = {
    "es": {"skip": "SALTAR COLA", "priority": "PRIORIDAD", "cinematic": "CINEMÁTICO", "photo": "SESIÓN DE FOTOS", "float": "FLOTAR", "party": "MODO FIESTA",
           "giant": "GIGANTE", "universe": "UNIVERSE DANCE"},
    "en": {"skip": "SKIP THE LINE", "priority": "PRIORITY", "cinematic": "CINEMATIC", "photo": "PHOTO SESSION", "float": "FLOAT", "party": "PARTY MODE",
           "giant": "GIANT", "universe": "UNIVERSE DANCE"},
}
DEFAULT_MODES = {  # gift = nombre del regalo de TikTok (lo cambia el usuario en el panel)
    "skip": {"gift": "Finger Heart", "label": "", "on": True},  # sale el siguiente, delante de todos
    "priority": {"gift": "Rose", "label": "", "on": True},  # label "" = el del idioma (MODE_LABEL)
    "cinematic": {"gift": "Love you", "label": "", "on": True},
    "photo": {"gift": "Perfume", "label": "", "on": True, "seconds": 7},  # posa en medio de la alfombra rodeado de fotógrafos
    "float": {"gift": "Capybara", "label": "", "on": True},  # recorre la alfombra flotando, con cámara dinámica y efectos
    "party": {"gift": "Doughnut", "label": "", "on": True, "seconds": 20},
    "giant": {"gift": "Hand Hearts", "label": "", "on": True, "seconds": 15},
    "universe": {"gift": "Money Gun", "label": "", "on": True},
}
DEFAULT_CFG = {"tiktok_user": "", "theme": "cozy-night", "lang": "", "link": "auto", "code": "",
               "roblox_user": "", "roblox_id": 0, "fame": {"on": True, "rate": 60},
               "walk_gap": 1.5, "cine_gap": 8, "screen": "off", "site": "", "stage_style": "minimal", "stage_floor": "auto", "stage_barrier": "auto", "stage_marks": "si", "stage_night": "dia", "rot_every": 0, "rot_off": [], "paused": False,
               "afk": False, "afk_minutes": 5, "auto": {"on": True, "stats": {}},
               "fast_on": 220, "fast_off": 100, "fast_x": 1.3,
               "jam": {"users": [], "auto": False, "every": 5},
               "phone": "", "restart": {"on": False, "at": 179, "on_warn": False, "on_gifts": False, "captcha": True}, "modes": DEFAULT_MODES, "ov": DEFAULT_OV, "ov_version": OV_VERSION, "times_version": TIMES_VERSION, "modes_version": MODES_VERSION}
STAGE_STYLES = ("minimal", "museo", "cine", "espacio", "pasarela", "vegas", "jardin", "ciudad")  # los mismos que ServerStorage.EscenariosRC del juego
STAGE_FLOORS = ("auto", "blanco", "negro", "gris", "crema", "rosa", "azul", "verde")  # los de C.FLOORS del juego
STAGE_BARRIERS = ("auto", "metal", "cuerda", "evento", "cristal", "neon", "seto", "cinta", "ninguna")  # los de C.BARRIERS del juego
STAGE_MARKS = ("si", "no")  # los de C.MARKS del juego
STAGE_NIGHT = ("dia", "noche")  # los de C.NIGHT del juego
STAGE_ROT = (0, 1, 2, 5, 10)  # minutos entre escenarios, los de C.ROT_TIMES del juego; 0 = no rotan
WALK_SECONDS, FLOAT_SECONDS = 20, 28  # lo que tarda en recorrer la alfombra: la fama va por tiempo
ROBLOX_NAME = re.compile(r"^@?([A-Za-z0-9_]{3,20})$")  # un comentario que es un usuario de Roblox
NORMAL_MAX, NORMAL_DROP = 400, 200
MAX_PER_DONOR = 100     # nadie tiene más de 100 desfiles pendientes aunque mande 200 rosas (no satura la cola)
FAIR_BIG, FAIR_CHUNK = 25, 5  # quien tiene más de 25 pendientes sale de 5 en 5, intercalado con los demás
QUICK_WAIT = 5          # quien manda pocas rosas (≤ FAIR_CHUNK), a los 5 s pasa delante: sale enseguida
# atasco: con más de fast_on (220) desfiles de regalo pendientes caminan ×fast_x (1.3) y salen más seguidos hasta bajar a fast_off (100)
# la cola normal (sin regalo) no pasa de 399: al llegar a 400 se borran los 200 primeros
# si no hay nadie en ninguna cola desfilan estos (usuarios del vídeo de referencia y conocidos), uno cada walk_gap s
FILLERS = ("Estrella0685", "Kirkwoohim", "Honeybear4500", "coquinha9608", "Parensaq", "Ruru_XdTT23", "Lisma_22",
           "amiplus98", "Builderman", "Shedletsky", "Linkmon99", "KreekCraft", "Coeptus", "Merely", "Tofuu", "Badcc",
           "Stickmasterluke", "Kohltastrophe", "DVplays", "Asimo3089", "BrightEyes", "Telamon", "Sorcus", "Flamingo", *BOTS)

lock = threading.Lock()
events = deque(maxlen=500)   # cola para Roblox Studio (local)
outbox = deque(maxlen=300)   # cola para el juego publicado (nube)
log = deque(maxlen=150)
seq = 0
state = {"status": "off", "error": "", "studio_seen": 0.0, "cloud_ok": 0.0, "cloud_error": "",
         "want": False, "tiktok": "", "avatars": 0, "next_walk": 0.0, "cine_ready": 0.0, "now": None, "party_until": 0.0,
         "afk_last": 0.0, "last_gift": 0.0, "last_giant": 0.0, "auto_racha": 0.0, "auto_party": 0.0}
# Tres colas; cada entrada {n: roblox, u: nick de TikTok, c: desfiles seguidos que le quedan}. Sale primero el cinemático
# (uno cada cine_gap s, para que su cámara acabe), luego las rosas por orden de llegada, luego la normal y si no, relleno.
cine_q, prio_q, normal_q = [], [], []
names = {}     # nick de TikTok -> usuario de Roblox (el último que escribió): los regalos de después ya saben quién es
pending = {}   # nick -> {prio, cine, giant, t}: regaló antes de escribir su usuario
donors = {}    # uid -> {uid, nick, avatar, coins, followers, following, t}
gift_catalog = {}  # nombre en minúsculas -> {id, name, coins, img}
client_box = {"client": None, "loop": None}


def merge(dst, src):
    """Rellena con los valores por defecto lo que falte (configs viejas)."""
    for k, v in src.items():
        if k not in dst or type(dst[k]) is not type(v):
            dst[k] = copy.deepcopy(v)
        elif isinstance(v, dict):
            merge(dst[k], v)
    return dst


def load_cfg():
    try:
        with open(CFG_PATH, encoding="utf-8") as f:
            c = json.load(f)
        c["modes"] = {k: {**DEFAULT_MODES[k], **(c.get("modes") or {}).get(k, {})} for k in DEFAULT_MODES}  # mantiene el orden del panel
        if c.get("ov_version") != OV_VERSION:  # diseño nuevo de los overlays (uno por sección)
            c["ov"], c["ov_version"] = copy.deepcopy(DEFAULT_OV), OV_VERSION
            for key, m in (c.get("modes") or {}).items():  # los nombres por defecto pasan a seguir el idioma
                if m.get("label") in (MODE_LABEL["es"].get(key), MODE_LABEL["en"].get(key)):
                    m["label"] = ""
        if c.get("times_version") != TIMES_VERSION:  # recorrido nuevo: tiempos nuevos
            # el juego encadena los cinemáticos (el siguiente empieza justo al acabar el anterior)
            c["walk_gap"], c["cine_gap"], c["times_version"] = 1.5, 8, TIMES_VERSION
            c["screen"] = "off"  # el usuario de quien desfila ya no sale en la pantalla
            g = (c.get("modes") or {}).get("giant")
            if g and g.get("gift") == "Perfume" and g.get("seconds") == 10:
                g["gift"], g["seconds"] = "Money Gun", 15
        if c.get("modes_version") != MODES_VERSION:
            g = (c.get("modes") or {}).get("giant")
            if g and g.get("gift") == "Money Gun":  # el Money Gun pasa a ser el Universe Dance
                g["gift"] = "Hand Hearts"
            c.setdefault("auto", {})["on"] = True
            c["modes_version"] = MODES_VERSION
        return merge(c, DEFAULT_CFG)
    except (OSError, ValueError):
        return copy.deepcopy(DEFAULT_CFG)


def save_cfg():
    os.makedirs(CFG_DIR, exist_ok=True)
    with open(CFG_PATH, "w", encoding="utf-8") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)


cfg = load_cfg()
ACC = Account(CFG_DIR, VERSION)


def premium_ok():
    """Pack Premium: AFK, ajustes del desfile, Live Checker (app del móvil) y reinicio del LIVE. Los overlays son gratis.
    El servidor dice si la cuenta lo tiene (prueba, admin o pack comprado)."""
    return bool(ACC.profile and ACC.profile.get("premium"))


def lock_reason():
    """None si se puede usar; si no, el motivo (también lo ve el juego)."""
    if not ACC.token or not ACC.profile:
        return "login"
    if ACC.profile.get("banned"):
        return "banned"
    if not ACC.allowed():
        return "trial_ended" if ACC.profile.get("trialEnded") else "no_plan"
    return None


def note(text, kind="info"):
    with lock:
        log.appendleft({"t": time.time(), "text": text, "kind": kind})


def push(ev, text=None, kind="info"):
    """Evento para el juego (ver arriba). No llamar con `lock` cogido."""
    global seq
    with lock:
        seq += 1
        events.append({**ev, "seq": seq, "t": time.time()})
        outbox.append(ev)
        if text:
            log.appendleft({"t": time.time(), "text": text, "kind": kind})


def game_on():
    return time.time() - state["studio_seen"] < 3 or time.time() - state["cloud_ok"] < 30


# ---------------- colas ----------------
def add_walks(q, name, nick, n):
    """n desfiles seguidos en q (cine_q o prio_q). Si ya está en esa cola, se le suman a los suyos:
    200 rosas = 200 desfiles seguidos suyos y después el siguiente."""
    for e in q:
        if e["n"].lower() == name.lower():
            e["c"] = min(MAX_PER_DONOR, e["c"] + n)
            break
    else:
        q.append({"n": name, "u": nick, "c": min(MAX_PER_DONOR, n), "t": time.time(), "quick": True})
    normal_q[:] = [e for e in normal_q if e["n"].lower() != name.lower()]  # ya desfila con regalo


def queued(name):
    return any(e["n"].lower() == name.lower() for q in (cine_q, prio_q, normal_q) for e in q)


def queue_view():
    return ([{"n": e["n"], "u": e["u"], "cine": e["c"], "prio": 0} for e in cine_q]
            + [{"n": e["n"], "u": e["u"], "cine": 0, "prio": e["c"]} for e in prio_q]
            + [{"n": e["n"], "u": e["u"], "cine": 0, "prio": 0} for e in normal_q])


def handle_comment(nick, text):
    m = ROBLOX_NAME.match((text or "").strip())
    if not m:
        return False
    name, nick = m.group(1), (nick or "")[:24]
    with lock:
        if nick:
            names[nick] = name
        p = pending.pop(nick, None) if nick else None
        p = p if p and time.time() - p["t"] < 900 else {}
        gifted = p.get("prio") or p.get("cine") or p.get("skip")
        if not gifted and queued(name):
            return False
        if p.get("cine"):
            add_walks(cine_q, name, nick, p["cine"])
        if p.get("prio"):
            add_walks(prio_q, name, nick, p["prio"])
        if p.get("skip"):
            skip_line(name, nick, p["skip"])
        if not gifted:
            normal_q.append({"n": name, "u": nick, "c": 1})
            if len(normal_q) >= NORMAL_MAX:
                del normal_q[:NORMAL_DROP]
    state["avatars"] += 1
    live_stats["avatars"] += 1
    note(f"💬 {nick}: {name}", "comment")
    for _ in range(int(p.get("giant") or 0)):
        giant(name, nick)
    for _ in range(int(p.get("universe") or 0)):
        universe(name, nick)
    for _ in range(int(p.get("float") or 0)):
        float_(name, nick)
    for _ in range(int(p.get("photo") or 0)):
        photo(name, nick)
    return True


def gift_owner(nick, kind, n):
    """Usuario de Roblox de quien regala; si aún no lo escribió, el regalo espera a que lo escriba."""
    with lock:
        name = names.get(nick)
        if not name:
            q = pending.setdefault(nick, {})
            q[kind] = (q.get(kind) or 0) + n
            q["t"] = time.time()
        return name


def boost(nick, kind, n):
    """Rosa: cada una = un desfile con prioridad (20 rosas = 20 desfiles, por orden de llegada).
    Te quiero: cada uno = un desfile en cinemático."""
    name = gift_owner(nick, kind, n)
    if name:
        with lock:
            add_walks(cine_q if kind == "cine" else prio_q, name, nick, n)


def giant(name, nick):
    state["last_giant"] = time.time()
    push({"k": "g", "n": name, "u": nick, "s": int(cfg["modes"]["giant"].get("seconds") or 10)}, f"🗿 {name}", "walk")


def universe(name, nick):
    """Universe Dance: 7 copias de quien regaló bailando 15 s en la escalera. El juego espera a que acabe el cinemático
    que haya y mientras baila no saca a nadie (los que llegan esperan y salen después)."""
    push({"k": "u", "n": name, "u": nick}, f"🌌 {name}", "walk")


def skip_line(name, nick, n):
    """Saltar cola: sale el siguiente, delante de los de rosa. Llamar con `lock` cogido."""
    for e in prio_q:
        if e["n"].lower() == name.lower():
            prio_q.remove(e)
            e["c"] = min(MAX_PER_DONOR, e["c"] + n)
            break
    else:
        e = {"n": name, "u": nick, "c": min(MAX_PER_DONOR, n), "t": time.time(), "quick": False}
    e["vip"] = True
    prio_q.insert(0, e)
    normal_q[:] = [x for x in normal_q if x["n"].lower() != name.lower()]


# ---------------- fama: quien pagó su turno gana seguidores mientras está en la alfombra ----------------
try:
    with open(FAME_PATH, encoding="utf-8") as _f:
        fame = json.load(_f)  # nick -> {n: roblox, f: seguidores}
except (OSError, ValueError):
    fame = {}


def fame_gain(nick, name, seconds):
    """(seguidores al empezar, los que gana). Cuanto más tiempo en la alfombra, más: lo cuenta el juego con su animación."""
    if not cfg["fame"]["on"] or not nick:
        return {}
    with lock:
        e = fame.setdefault(nick, {"n": name, "f": 0})
        gain = int(float(cfg["fame"]["rate"]) * seconds * random.uniform(0.8, 1.2))
        start = e["f"]
        e.update(n=name, f=start + gain)
        try:
            os.makedirs(CFG_DIR, exist_ok=True)
            with open(FAME_PATH, "w", encoding="utf-8") as f:
                json.dump(fame, f, ensure_ascii=False)
        except OSError:
            pass
    return {"fs": start, "fg": gain}


def fame_top():
    with lock:
        return [{"u": k, **v} for k, v in sorted(fame.items(), key=lambda kv: -kv[1]["f"])[:10]]


def float_(name, nick):
    """Capibara: recorre la alfombra flotando, con cámara dinámica y efectos."""
    push({"k": "y", "n": name, "u": nick, **fame_gain(nick, name, FLOAT_SECONDS)}, f"🫧 {name}", "walk")


def photo(name, nick):
    """Sesión de fotos: posa en medio de la alfombra rodeado de fotógrafos y flashes."""
    secs = int(cfg["modes"]["photo"].get("seconds") or 7)
    push({"k": "f", "n": name, "u": nick, "s": secs, **fame_gain(nick, name, secs)}, f"📸 {name}", "walk")


def mode_for(gift):
    g = (gift or "").strip().lower()
    for key, m in cfg["modes"].items():
        if m.get("on") and m.get("gift", "").strip().lower() == g:
            return key
    return None


# estadísticas del directo actual para Stats Fluxy (solo gente de verdad: los rellenos y eventos automáticos no cuentan).
# Cada sala de TikTok es un directo: al terminar (o al conectar a otra sala) se guarda en el historial y se empieza de cero.
LIVE_ZERO = {"avatars": 0, "gifts": 0, "coins": 0, "roses": 0, "by_gift": {}, "gift_img": {}, "likes": 0,
             "views": 0, "viewers": 0, "peak": 0, "follows": 0, "shares": 0}
live_stats = {**copy.deepcopy(LIVE_ZERO), "donors": set(), "start": 0.0}
phone_alerts = deque(maxlen=10)  # avisos para el móvil: {id, t, text, kind, tag}
HIST_PATH = os.path.join(CFG_DIR, "live_history.json")
try:
    with open(HIST_PATH, encoding="utf-8") as _f:
        live_history = json.load(_f)
except (OSError, ValueError):
    live_history = []


def live_stats_reset():
    with lock:
        live_stats.update(copy.deepcopy(LIVE_ZERO), donors=set(), start=time.time())


def live_summary():
    with lock:
        ls = live_stats
        gifts = sorted(ls["by_gift"].items(), key=lambda kv: -kv[1])[:12]
        top = sorted((d for d in donors.values() if d.get("t", 0) >= ls["start"] and not d.get("test")), key=lambda d: -d.get("coins", 0))[:5]
        return {"id": secrets.token_hex(4), "tiktok": state.get("tiktok", ""), "start": state.get("room_start") or ls["start"],
                "end": time.time(), "peak": ls["peak"], "views": ls["views"], "likes": ls["likes"], "follows": ls["follows"],
                "shares": ls["shares"], "donors": len(ls["donors"]), "gifts": ls["gifts"], "coins": ls["coins"],
                "avatars": ls["avatars"], "by_gift": [{"n": n, "c": c, "img": ls["gift_img"].get(n, "")} for n, c in gifts],
                "top": [{"nick": d.get("nick", ""), "avatar": d.get("avatar", ""), "coins": d.get("coins", 0)} for d in top]}


def live_close():
    """El directo terminó: sus estadísticas van al historial (últimos 50) y las del directo vuelven a cero."""
    if live_stats["start"] and (live_stats["gifts"] or live_stats["likes"] or live_stats["peak"] or live_stats["avatars"]):
        live_history.append(live_summary())
        del live_history[:-50]
        try:
            os.makedirs(CFG_DIR, exist_ok=True)
            with open(HIST_PATH, "w", encoding="utf-8") as f:
                json.dump(live_history, f, ensure_ascii=False)
        except OSError:
            pass
    live_stats_reset()
    state["room_id"] = None


def phone_alert(text, kind="warn", tag=None):
    """Aviso al móvil (suena 5 veces). El mismo aviso (o la misma clase, tag) no se repite en 10 min."""
    last = next((a for a in phone_alerts if (a.get("tag") or a["text"]) == (tag or text)), None)
    if last and time.time() - last["t"] < 600:
        return
    phone_alerts.appendleft({"id": secrets.token_hex(4), "t": time.time(), "text": text[:160], "kind": kind, "tag": tag})
    note("📱 " + text[:80], "warn")


def live_stats_view():
    with lock:
        top = sorted(live_stats["by_gift"].items(), key=lambda kv: -kv[1])[:30]
        return {"avatars": live_stats["avatars"], "gifts": live_stats["gifts"], "coins": live_stats["coins"],
                "roses": live_stats["roses"], "donors": len(live_stats["donors"]), "by_gift": dict(top)}


recent_gifts, gift_seq = deque(maxlen=30), [0]  # para el overlay de animaciones de regalos


def handle_gift(user, gift, count, diamonds, test=False):
    """user = {uid, nick, avatar, followers, following}. test = regalo de prueba del panel: hace su animación pero no
    cuenta en las estadísticas del directo (ni en la app del móvil, el historial o el modo automático)."""
    nick, count, gift_img = user["nick"][:24], int(count), user.pop("gift_img", "")
    with lock:
        name = (gift or "?")[:30]
        img = gift_img or (gift_catalog.get(name.lower()) or {}).get("img")
        if not test:
            live_stats["gifts"] += count
            live_stats["coins"] += int(diamonds or 0) * count
            live_stats["donors"].add(user["uid"] or nick)
            live_stats["by_gift"][name] = live_stats["by_gift"].get(name, 0) + count
            if img:
                live_stats["gift_img"][name] = img
            if name.lower() == "rose":
                live_stats["roses"] += count
        d = donors.setdefault(user["uid"] or nick, {**user, "coins": 0})
        d.update({k: v for k, v in user.items() if v not in ("", None)})
        d["coins"] += int(diamonds or 0) * count
        d["test"] = test and d.get("test", True)  # alguien con un solo regalo de verdad ya cuenta
        d["t"] = state["last_gift"] = time.time()
        if not test:
            gift_log.append((d["t"], int(diamonds or 0) * count))
        d["gift"] = gift
        gift_seq[0] += 1
        recent_gifts.append({"id": gift_seq[0], "t": d["t"], "nick": nick, "uid": user["uid"], "avatar": d.get("avatar") or "",
                             "gift": gift, "img": img or "", "n": count, "coins": int(diamonds or 0) * count})
    key = mode_for(gift)
    label = mode_label(key) if key else ""
    if key == "priority":
        boost(nick, "prio", count)
    elif key == "skip":
        name = gift_owner(nick, "skip", count)
        if name:
            with lock:
                skip_line(name, nick, count)
    elif key == "photo":
        name = gift_owner(nick, "photo", count)
        for _ in range(count if name else 0):
            photo(name, nick)
    elif key == "cinematic":
        boost(nick, "cine", count)
    elif key == "giant":
        name = gift_owner(nick, "giant", count)
        for _ in range(count if name else 0):
            giant(name, nick)
    elif key == "universe":
        name = gift_owner(nick, "universe", count)
        for _ in range(count if name else 0):
            universe(name, nick)
    elif key == "float":
        name = gift_owner(nick, "float", count)
        for _ in range(count if name else 0):
            float_(name, nick)
    elif key == "party":
        secs = int(cfg["modes"]["party"].get("seconds") or 20) * count
        state["party_until"] = max(state["party_until"], time.time()) + secs
        ev = {"k": "p", "s": secs}
        if names.get(nick):  # su usuario de Roblox sale en la pantalla mientras dura (si no lo ha escrito, sigue el link)
            ev["n"] = names[nick]
        push(ev)
    note(f"🎁 {nick} → {gift} x{count}" + (f" · {label}" if label else ""), "gift")


# ---------------- eventos automáticos (solo admin; apagados por defecto) ----------------
# Si el directo se queda sin regalos lanza un evento: una racha de desfiles seguidos de un modelo, la fiesta o un gigante.
# Los modelos van sin @ de TikTok y no entran en la cola ni en los donadores: no se hacen pasar por gente que ha regalado.
# Aprende qué racha trae más monedas en los 2 min siguientes y la repite más (epsilon-greedy; nunca más de 8 seguidos).
AUTO_MODELS = ("Lapyna240", "chicasrgr", "lizakuraaa", "Aleexandra013", "GerlandWilhelmus", "kinglordkingexe",
               "SKYLINE7564321", "Robloxfoxino", "cloe110789", "Cerry0622", "nerii_arii", "RomixRock", "Zenguissant",
               "Dar0_Happy", "bacon_ma667", "Igety7", "sonic433443", "EyesMc000")
RACHAS = (2, 3, 4, 6, 8)
AUTO_IDLE_RACHA, AUTO_IDLE_PARTY, AUTO_GIANT_EVERY, AUTO_WINDOW = 90, 180, 300, 120
auto_q = []                     # rachas pendientes {n, u: "", c}; salen después de los de verdad
gift_log = deque(maxlen=3000)   # (t, monedas) de los regalos reales
auto_wait = []                  # (t, clave): eventos lanzados cuyo resultado aún se está midiendo


def coins_between(t0, t1):
    return sum(c for t, c in gift_log if t0 <= t < t1)


def auto_score(key):
    n, coins = cfg["auto"]["stats"].get(key, (0, 0))
    return coins / n if n else float("inf")  # lo que nunca se ha probado va primero


def auto_event(kind, size=0, manual=False):
    """kind: racha (size desfiles de un modelo), party o giant. Devuelve el texto del registro."""
    now, model = time.time(), random.choice(AUTO_MODELS)
    if kind == "racha":
        size = int(size) or (random.choice(RACHAS) if random.random() < 0.25 else min(RACHAS, key=lambda r: -auto_score(f"racha{r}")))
        size = max(1, min(8, size))
        with lock:
            auto_q.append({"n": model, "u": "", "c": size})
        state["auto_racha"], key, text = now, f"racha{size}", f"🤖 {model} ×{size}"
    elif kind == "party":
        secs = int(cfg["modes"]["party"].get("seconds") or 20)
        state["party_until"] = max(state["party_until"], now) + secs
        push({"k": "p", "s": secs})
        state["auto_party"], key, text = now, "party", f"🤖 🎉 {secs} s"
    else:
        giant(model, "")
        key, text = "giant", f"🤖 🗿 {model}"
    if not manual:
        auto_wait.append((now, key))
    note(text, "walk")
    return text


def auto_loop():
    while True:
        time.sleep(5)
        now = time.time()
        for t, key in [w for w in auto_wait if now - w[0] >= AUTO_WINDOW]:  # resultado: monedas en los 2 min siguientes
            auto_wait.remove((t, key))
            n, coins = cfg["auto"]["stats"].get(key, (0, 0))
            cfg["auto"]["stats"][key] = (n + 1, coins + coins_between(t, t + AUTO_WINDOW))
            save_cfg()
        if cfg["jam"]["auto"] and ACC.is_admin() and state["status"] == "live" and game_on() and not cfg["paused"] \
                and not lock_reason() and now >= state.get("jam_next", 0):
            real = backlog() - jam_pending()  # con muchos regalos de verdad no hace falta: lo intenta 5 min después
            state["jam_next"] = now + (JAM_RETRY if real > JAM_REAL_MAX else max(1, float(cfg["jam"]["every"])) * 60)
            if real <= JAM_REAL_MAX:
                jam()
        if not (cfg["auto"]["on"] and state["status"] == "live" and game_on()) or cfg["paused"] or lock_reason():
            continue
        quiet = now - max(state["last_gift"], state.get("live_since", 0))
        if quiet >= AUTO_IDLE_PARTY and now - state["auto_party"] >= AUTO_IDLE_PARTY and now > state["party_until"]:
            auto_event("party")
        elif now - max(state["last_giant"], state.get("live_since", 0)) >= AUTO_GIANT_EVERY:
            auto_event("giant")
        elif quiet >= AUTO_IDLE_RACHA and now - state["auto_racha"] >= AUTO_IDLE_RACHA and not auto_q:
            auto_event("racha")


# ---------------- atasco artificial (solo admin) ----------------
# Mete en las colas rosas, cinemáticos y a veces un gigante de los usuarios de la lista (Roblox + @TikTok), como si
# hubieran regalado. Nunca Universe Dance. No cuenta en las estadísticas del directo. Nunca más de JAM_MAX a la vez.
JAM_MAX, JAM_REAL_MAX, JAM_RETRY = 140, 100, 300
JAM_ROSES = (1, 1, 2, 3, 5, 5, 8, 10, 10, 15, 20, 30, 49)


def jam_pending():
    return sum(e["c"] for q in (prio_q, cine_q) for e in q if e.get("fake"))


def jam():
    users = [u for u in cfg["jam"]["users"] if u[0]]
    if not users:
        return 0
    with lock:
        room = JAM_MAX - jam_pending()
        goal, added, giants = random.randint(min(60, room), room) if room > 0 else 0, 0, []
        while added < goal:
            name, nick = random.choice(users)
            r = random.random()
            if r < 0.04 and not giants:
                giants.append((name, nick))
                continue
            q, n = (cine_q, random.randint(1, 2)) if r < 0.25 else (prio_q, random.choice(JAM_ROSES))
            n = min(n, goal - added)
            add_walks(q, name, nick, n)
            for e in q:
                if e["n"].lower() == name.lower():
                    e["fake"] = True
            added += n
    for name, nick in giants:
        giant(name, nick)
    note(f"🚧 Atasco: {added}" + (" + 🗿" if giants else ""), "walk")
    return added


def take(q):
    e = q[0]
    e["c"] -= 1
    if e["c"] <= 0:
        q.pop(0)
    return e


def take_prio():
    """Rosas: el que manda pocas (≤ FAIR_CHUNK) pasa delante a los QUICK_WAIT s (por si era una racha que sigue llegando);
    el que tiene más de FAIR_BIG pendientes sale de FAIR_CHUNK en FAIR_CHUNK y deja pasar al siguiente, hasta que le
    quedan FAIR_BIG: a partir de ahí salen todos los suyos seguidos. Así uno que manda 1000 no tapa a los demás."""
    now = time.time()
    for i, e in enumerate(prio_q):
        if e.get("quick") and now - e["t"] >= QUICK_WAIT:
            e["quick"] = False
            if e["c"] <= FAIR_CHUNK and i > 0:
                prio_q.insert(0, prio_q.pop(i))
    e = prio_q[0]
    e["c"] -= 1
    e["run"] = e.get("run", 0) + 1
    if e["c"] <= 0:
        prio_q.pop(0)
    elif e["c"] > FAIR_BIG and e["run"] >= FAIR_CHUNK and len(prio_q) > 1:
        e["run"] = 0
        prio_q.insert(1, prio_q.pop(0))
    elif e["run"] >= FAIR_CHUNK and e["c"] > FAIR_BIG:
        e["run"] = 0
    return e


def backlog():
    return sum(e["c"] for e in prio_q) + sum(e["c"] for e in cine_q)


def walk_loop():
    """Uno cada walk_gap s: cinemático (si la cámara del anterior ya acabó) > rosas > normal > relleno.
    Así nunca hay pasarela vacía ni nadie esperando quieto."""
    recent = deque(maxlen=8)
    while True:
        time.sleep(0.25)
        now = time.time()
        if cfg["paused"] or lock_reason() or not game_on() or now < state["next_walk"]:
            continue
        with lock:
            if cine_q and now >= state["cine_ready"]:
                e, kind = take(cine_q), "cine"
            elif prio_q:
                e, kind = take_prio(), "prio"
            elif normal_q:
                e, kind = take(normal_q), "normal"
            elif auto_q:
                e, kind = take(auto_q), "auto"
            else:
                e, kind = {"n": random.choice([f for f in FILLERS if f not in recent]), "u": ""}, "filler"
        recent.append(e["n"])
        walk(e, kind)


def walk(e, kind="normal"):
    now = time.time()
    cine, prio = kind == "cine", kind == "prio"
    pk = cfg if premium_ok() else DEFAULT_CFG  # sin el pack: los tiempos de siempre
    b = backlog()  # atasco de regalos: más rápido para que la cola avance
    state["fast"] = b > pk["fast_on"] or (state.get("fast", False) and b > pk["fast_off"])
    fast = float(pk["fast_x"]) if state["fast"] else 1
    state["next_walk"] = now + float(pk["walk_gap"]) / fast
    if cine:  # el siguiente cinemático sale cuando acaba la cámara de éste (+2 s)
        state["cine_ready"] = now + float(pk["cine_gap"])
    state["now"] = {"n": e["n"], "u": e["u"], "prio": prio, "cine": cine, "t": now}
    vip = bool(e.get("vip"))
    tags = (" ⚡" if vip else " 🌹" if prio else "") + (" 🎬" if cine else "")
    paid = fame_gain(e["u"], e["n"], WALK_SECONDS) if (prio or cine) and not e.get("fake") else {}  # la fama es sólo de quien pagó su turno
    push({"k": "w", "n": e["n"], "u": e["u"], "c": cine, "h": prio and not vip, **({"v": True} if vip else {}), **({"b": BOTS[e["n"]]} if not e["u"] and e["n"] in BOTS else {}), **paid, **({"f": fast} if fast != 1 else {})}, None if kind in ("filler", "auto") else f"🚶 {e['n']}{tags}", "walk")
    ev = {"k": "t", "style": cfg["stage_style"], "floor": cfg["stage_floor"], "barrier": cfg["stage_barrier"], "marks": cfg["stage_marks"], "night": cfg["stage_night"], "rot": {"every": cfg["rot_every"], "off": cfg["rot_off"]}, "text": e["n"] if cfg["screen"] == "walker" and premium_ok() else ""}
    if ACC.is_admin():  # el link de la pantalla sólo lo cambia el admin (en su servidor); el resto ve el de siempre
        ev["site"] = cfg["site"]
    if ev != state.get("stage_ev") or now - state.get("stage_t", 0) > 30:  # también cada 30 s: si el juego se reinicia, lo recupera
        state["stage_ev"], state["stage_t"] = ev, now
        push(ev)


# ---------------- TikTok ----------------
def url0(img):
    try:
        return img.m_urls[0]
    except Exception:
        return ""


def user_info(u):
    fi = getattr(u, "follow_info", None)
    return {"uid": getattr(u, "unique_id", "") or "", "nick": getattr(u, "nickname", "") or getattr(u, "unique_id", "") or "?",
            "avatar": url0(getattr(u, "avatar_thumb", None)),
            "followers": getattr(fi, "follower_count", 0) or 0, "following": getattr(fi, "following_count", 0) or 0}


def store_gifts(data):
    for g in data.get("gifts", []):
        gift_catalog[g["name"].lower()] = {"id": g["id"], "name": g["name"], "coins": g.get("diamond_count", 0),
                                           "img": (g.get("image") or {}).get("url_list", [""])[0]}


def load_gift_catalog():
    async def go():
        return await TikTokLiveClient(unique_id="tiktok").web.fetch_gift_list()
    try:
        store_gifts(asyncio.run(go()))
    except Exception as ex:
        print("No se pudo leer la lista de regalos:", ex)


async def live_once(unique_id):
    client = TikTokLiveClient(unique_id="@" + unique_id)
    client_box["client"] = client

    @client.on(ConnectEvent)
    async def _c(_):
        rid = str(getattr(client, "room_id", "") or "")
        if rid != state.get("room_id") or state.get("tiktok") != unique_id:  # otra sala = otro directo
            if state.get("room_id"):
                live_close()
            live_stats_reset()
            state["room_id"] = rid
        try:  # hora a la que empezó el LIVE (para reiniciarlo a las 2:59 aunque LIVE Studio esté tapado)
            info = await client.web.fetch_room_info()
            state["room_start"] = float(info.get("create_time") or 0) or time.time()
        except Exception:
            state["room_start"] = time.time()
        state.update(status="live", error="", tiktok=unique_id, live_since=time.time())
        note(f"🟢 LIVE @{unique_id}", "ok")
        threading.Thread(target=ACC.beat_now, daemon=True).start()

    @client.on(DisconnectEvent)
    async def _d(_):
        note("🔌 TikTok", "warn")

    @client.on(LiveEndEvent)
    async def _e(_):
        state["want"] = False
        note("⏹️ LIVE", "warn")
        live_close()
        if not state.get("restarting"):
            phone_alert("⏹️ Tu LIVE terminó")

    @client.on(LikeEvent)
    async def _lk(ev):
        live_stats["likes"] = max(live_stats["likes"], int(ev.total or 0))

    @client.on(RoomUserSeqEvent)
    async def _rs(ev):
        live_stats["viewers"] = int(ev.m_total or 0)
        live_stats["peak"] = max(live_stats["peak"], live_stats["viewers"])
        live_stats["views"] = max(live_stats["views"], int(ev.total_user or 0))

    @client.on(FollowEvent)
    async def _fw(_):
        live_stats["follows"] += 1

    @client.on(ShareEvent)
    async def _sh(_):
        live_stats["shares"] += 1

    @client.on(RoomVerifyEvent)
    async def _rv(ev):
        phone_alert("🧩 TikTok pide verificación (captcha)" + (f": {ev.content}" if ev.content else ""), "danger", "verify")
        auto_restart("warn")

    @client.on(NoticeEvent)
    async def _nt(ev):
        phone_alert("⚠️ Aviso de TikTok: " + (ev.content or "tu LIVE recibió un aviso"), "danger", "notice")
        auto_restart("warn")

    @client.on(CommentEvent)
    async def _cm(ev):
        handle_comment(ev.user.nickname or ev.user.unique_id, ev.comment)

    @client.on(GiftEvent)
    async def _g(ev):
        if ev.streaking:  # combo en curso: se cuenta al terminar
            return
        g = ev.gift
        handle_gift(user_info(ev.user) | {"gift_img": url0(getattr(g, "image", None))}, g.name, max(1, ev.repeat_count or 1), g.diamond_count)

    await client.connect()


def run_client(unique_id):
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    client_box["loop"] = loop
    while state["want"]:
        state.update(status="connecting", error="")
        try:
            loop.run_until_complete(live_once(unique_id))
        except Exception as ex:
            name = type(ex).__name__
            if "Offline" in name or "NotFound" in name:
                state.update(want=False, error="offline")
            else:
                state["error"] = f"{name}: {ex}"[:160]
        if state["want"]:
            note("🔁 …", "warn")
            time.sleep(5)
    state["status"], state["live_end"] = "off", time.time()
    client_box.update(client=None, loop=None)


def connect(unique_id):
    disconnect()
    state["want"] = True
    threading.Thread(target=run_client, args=(unique_id,), daemon=True).start()


def disconnect():
    state["want"] = False
    c, loop = client_box["client"], client_box["loop"]
    if c and loop and loop.is_running():
        asyncio.run_coroutine_threadsafe(c.disconnect(), loop)
        for _ in range(30):
            if client_box["loop"] is None:
                break
            time.sleep(0.1)
    state["status"] = "off"


# ---------------- modo AFK ----------------
# Roblox echa a los 20 min sin tocar nada: cada X min se pone delante la ventana de Roblox, se pulsa Espacio
# (salto) y se vuelve a la ventana que tenías. El juego además se reconecta solo a los 19 min (AfkRejoin).
user32 = ctypes.windll.user32


class KEYBDINPUT(ctypes.Structure):
    _fields_ = [("wVk", wt.WORD), ("wScan", wt.WORD), ("dwFlags", wt.DWORD), ("time", wt.DWORD), ("dwExtraInfo", ctypes.c_size_t)]


class MOUSEINPUT(ctypes.Structure):
    _fields_ = [("dx", wt.LONG), ("dy", wt.LONG), ("mouseData", wt.DWORD), ("dwFlags", wt.DWORD), ("time", wt.DWORD),
                ("dwExtraInfo", ctypes.c_size_t)]


class INPUT(ctypes.Structure):
    class _U(ctypes.Union):
        _fields_ = [("ki", KEYBDINPUT), ("mi", MOUSEINPUT)]
    _anonymous_ = ("u",)
    _fields_ = [("type", wt.DWORD), ("u", _U)]


def key_tap(scan=0x39, hold=0.12):  # 0x39 = Espacio (por scancode: Roblox lee la tecla física)
    for flags in (0x0008, 0x0008 | 0x0002):  # KEYEVENTF_SCANCODE, + KEYUP
        i = INPUT(type=1, ki=KEYBDINPUT(0, scan, flags, 0, 0))
        user32.SendInput(1, ctypes.byref(i), ctypes.sizeof(INPUT))
        time.sleep(hold)


def roblox_window():
    found = []

    @ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)
    def cb(h, _):
        buf = ctypes.create_unicode_buffer(64)
        user32.GetWindowTextW(h, buf, 64)
        if buf.value == "Roblox" and user32.IsWindowVisible(h):
            found.append(h)
        return True
    user32.EnumWindows(cb, 0)
    return found[0] if found else None


def focus(h):
    user32.keybd_event(0x12, 0, 0, 0)  # un Alt "suelta" el bloqueo de Windows a SetForegroundWindow
    user32.keybd_event(0x12, 0, 2, 0)
    user32.SetForegroundWindow(h)


def afk_nudge():
    h = roblox_window()
    if not h:
        return False
    prev, mini = user32.GetForegroundWindow(), user32.IsIconic(h)
    if mini:
        user32.ShowWindow(h, 9)  # SW_RESTORE
    focus(h)
    time.sleep(0.4)
    key_tap()
    time.sleep(0.2)
    if mini:
        user32.ShowWindow(h, 6)  # SW_MINIMIZE
    if prev and prev != h:
        focus(prev)
    return True


def afk_loop():
    while True:
        time.sleep(5)
        if cfg["afk"] and premium_ok() and time.time() - state["afk_last"] >= max(1, float(cfg["afk_minutes"])) * 60:
            state["afk_last"] = time.time()
            note("🕹️ AFK: " + ("Roblox ✓" if afk_nudge() else "Roblox ✗"), "info")


# ---------------- Live Checker (app del móvil) y TikTok LIVE Studio ----------------
# El programa manda cada 10 s las estadísticas del directo y los avisos a `live-checker`; la app los lee con el código.
PHONE_API = "https://dcepxcltgzipkmzpptzn.supabase.co/functions/v1/live-checker"
APK_URL = "https://github.com/cristiancordova1207/Live-Checker"


def phone_payload():
    with lock:
        ls = live_stats
        gifts = sorted(ls["by_gift"].items(), key=lambda kv: -kv[1])[:24]
        top = sorted((d for d in donors.values() if d.get("t", 0) >= ls["start"] and not d.get("test")), key=lambda d: -d.get("coins", 0))[:5]
        r = cfg["restart"]
        start = state.get("room_start") or ls["start"]
        return {"v": 1, "t": time.time(), "live": state["status"] == "live", "tiktok": state.get("tiktok", ""),
                "start": start, "since": ls["start"], "viewers": ls["viewers"], "peak": ls["peak"], "views": ls["views"],
                "likes": ls["likes"], "follows": ls["follows"], "shares": ls["shares"],
                "donors": len(ls["donors"]), "gifts": ls["gifts"], "coins": ls["coins"], "avatars": ls["avatars"],
                "by_gift": [{"n": n, "c": c, "img": ls["gift_img"].get(n, "")} for n, c in gifts],
                "top": [{"nick": d.get("nick", ""), "avatar": d.get("avatar", ""), "coins": d.get("coins", 0)} for d in top],
                "history": live_history[:-11:-1], "alerts": list(phone_alerts), "restart": {"on": r["on"] and premium_ok(), "at": r["at"],
                                                           "busy": bool(state.get("restarting"))}}


def phone_send():
    body = json.dumps({"k": cfg["phone"], "d": phone_payload()}).encode()
    req = urllib.request.Request(PHONE_API, body, {"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=10):
            state["phone_ok"] = time.time()
    except Exception as ex:
        state["phone_err"] = str(ex)[:120]


def phone_loop():
    """Cada 10 s en directo (cada 60 s si no) y al momento si hay un aviso nuevo."""
    last, last_alert = 0.0, None
    while True:
        time.sleep(1)
        if not cfg["phone"] or not premium_ok():  # Live Checker es del pack
            continue
        top = phone_alerts[0]["id"] if phone_alerts else None
        every = 10 if state["status"] == "live" else 60
        if top != last_alert or time.time() - last >= every:
            last, last_alert = time.time(), top
            phone_send()


def studio_loop():
    """Cada 30 s mira LIVE Studio (si se ve): contador del LIVE y avisos. A las 2:59 (ajustable) reinicia el LIVE."""
    while True:
        time.sleep(30)
        if state["status"] != "live" or state.get("restarting"):
            continue
        elapsed = None
        try:
            seen = studio.look()
        except Exception:
            seen = None
        if seen:
            lines, size = seen
            tm = studio.read_timer(lines, size)
            if tm:
                elapsed = tm[0]
            off, warn = studio.gifts_off(lines, size), studio.alerts(lines, size)
            if cfg["restart"]["captcha"] and premium_ok() and studio.captcha(lines, size):
                if not state.get("captcha_watch"):  # no es una advertencia: lo resuelves tú y el LIVE sigue
                    threading.Thread(target=watch_captcha, daemon=True).start()
                off = warn = None
            if off:  # un solo aviso por clase (el OCR lee varias líneas y cada vez un poco distinto)
                phone_alert("🎁 Regalos desactivados: " + " ".join(off)[:140], "danger", "gifts")
            elif warn:
                phone_alert("⚠️ LIVE Studio: " + " ".join(warn)[:140], "danger", "warn")
            if off:
                auto_restart("gifts")
            elif warn:
                auto_restart("warn")
        if elapsed is None and state.get("room_start"):
            elapsed = time.time() - state["room_start"]
        state["live_elapsed"] = elapsed
        r = cfg["restart"]
        if r["on"] and elapsed is not None and elapsed >= float(r["at"]) * 60 and not state.get("captcha_watch"):
            auto_restart("time")


def watch_captcha():
    """Captcha de inactividad: no se toca (lo resuelves tú). Avisa al móvil y mira cada 3 s; cuando desaparece, el LIVE
    sigue. Si a los 4:30 sigue ahí (TikTok lo cancela a los 5 min), reinicia el LIVE."""
    state["captcha_watch"] = True
    try:
        note("🧩 Captcha de inactividad en LIVE Studio: resuélvelo (5 min)", "warn")
        phone_alert("🧩 Captcha en LIVE Studio: resuélvelo, tienes 5 min", "danger", "captcha")
        t0, reminded = time.time(), False
        while time.time() - t0 < 270:
            time.sleep(3)
            try:
                seen = studio.look()
            except Exception:
                seen = None
            if seen and not studio.captcha(*seen):
                note("✅ Captcha resuelto: el LIVE sigue", "ok")
                phone_alert("✅ Captcha resuelto: el LIVE sigue", "ok", "captcha")
                return
            if not reminded and time.time() - t0 > 150:
                reminded = True
                phone_alert("🧩 Captcha sin resolver: quedan ~2 min", "danger", "captcha2")
        note("⏱️ Captcha sin resolver: reiniciando el LIVE", "warn")
        phone_alert("⏱️ Captcha sin resolver: reinicio el LIVE", "danger", "captcha")
        restart_live()
    finally:
        state["captcha_watch"] = False


def auto_restart(why):
    """Reinicio automático (solo admin), cada motivo con su casilla: time = a los X min, warn = advertencia, gifts = regalos
    desactivados. Para warn/gifts primero cierra el aviso. Como mucho uno cada 10 min (o cada X min si el programado es más corto): no entra en bucle."""
    r = cfg["restart"]
    if not premium_ok() or not {"time": r["on"], "warn": r["on_warn"], "gifts": r["on_gifts"]}[why] \
            or state.get("restarting") or time.time() - state.get("restart_last", 0) < (min(600, r["at"] * 60) if why == "time" else 600):
        return
    note({"time": "🔁 Reinicio programado del LIVE", "warn": "🔁 Advertencia: reiniciando el LIVE",
          "gifts": "🔁 Regalos desactivados: reiniciando el LIVE"}[why], "warn")
    threading.Thread(target=restart_live, kwargs={"dismiss": why != "time"}, daemon=True).start()


def find_ffmpeg():
    exe = shutil.which("ffmpeg")
    if exe:
        return exe
    import glob  # instalado con winget pero sin PATH en este proceso
    hits = glob.glob(os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "WinGet", "Packages", "*FFmpeg*", "*", "bin", "ffmpeg.exe"))
    return hits[0] if hits else None


def record_screen(secs=120):
    """Graba la pantalla (con el ratón) `secs` segundos en Videos, para ver qué hizo el reinicio si falla."""
    exe = find_ffmpeg()
    if not exe:
        note("🎥 No se graba el reinicio: falta ffmpeg (winget install ffmpeg)", "warn")
        return
    folder = os.path.join(os.path.expanduser("~"), "Videos")
    os.makedirs(folder, exist_ok=True)
    out = os.path.join(folder, f"RedCarpet-reinicio-{datetime.now():%Y%m%d-%H%M%S}.mp4")
    area = []  # sólo la pantalla de LIVE Studio (con dos pantallas, todo junto se vería diminuto)
    studio.dpi_aware()
    h = studio.window()
    if h:
        x0, y0, x1, y1 = studio.monitor(h)
        area = ["-offset_x", str(x0), "-offset_y", str(y0), "-video_size", f"{(x1 - x0) // 2 * 2}x{(y1 - y0) // 2 * 2}"]
    try:
        subprocess.Popen([exe, "-hide_banner", "-loglevel", "error", "-f", "gdigrab", "-framerate", "15", "-draw_mouse", "1",
                          *area, "-i", "desktop", "-t", str(secs), "-vf", "scale='min(1920,iw)':-2", "-c:v", "libx264",
                          "-preset", "ultrafast", "-crf", "28", "-pix_fmt", "yuv420p", out],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=0x08000000)
        note(f"🎥 Grabando el reinicio ({secs // 60} min): {out}", "info")
    except OSError as ex:
        note(f"🎥 No se pudo grabar: {ex}", "warn")


def restart_live(dry=False, dismiss=False):
    """Terminar e iniciar el LIVE otra vez (como en el vídeo), reconectar y activar Favorito del público.
    dry = sólo comprobar que se ve el contador y el menú «Finalizar LIVE» (no termina nada)."""
    if state.get("restarting"):
        return "busy"
    state.update(restarting=True, restart_last=time.time())
    if not dry:
        record_screen()
    try:
        if not studio.is_admin():
            raise studio.Step("abre Red Carpet como administrador (TikTok LIVE Studio lo es)")
        if dismiss:
            studio.dismiss(note)
        st = studio.Studio(note)
        st.run(dry)
        if dry:
            return "ok"
        tik = cfg["tiktok_user"] or state.get("tiktok", "")
        time.sleep(10)
        for _ in range(6):
            connect(tik)
            for _ in range(20):
                time.sleep(1)
                if state["status"] == "live":
                    break
            if state["status"] == "live":
                break
        if state["status"] != "live":
            raise studio.Step("no se pudo conectar al LIVE nuevo")
        note("🟢 Conectado al LIVE nuevo", "ok")
        try:
            st.favorite()
        except studio.Step as ex:
            phone_alert(f"💝 Favorito del público: {ex}", "warn")
        phone_alert("🔁 LIVE reiniciado y conectado ✓", "ok")
        return "ok"
    except Exception as ex:
        msg = str(ex) if isinstance(ex, studio.Step) else f"{type(ex).__name__}: {ex}"
        note(f"🔁 Reinicio del LIVE: {msg}", "warn")
        if not dry:
            phone_alert(f"❌ No se pudo reiniciar el LIVE: {msg}", "danger")
        return msg
    finally:
        state["restarting"] = False


def phone_view():
    return {"code": cfg["phone"], "apk": APK_URL, "ok": time.time() - state.get("phone_ok", 0) < 90,
            "premium": premium_ok(), "elevated": studio.is_admin(), "restart": cfg["restart"],
            "restarting": bool(state.get("restarting")), "elapsed": state.get("live_elapsed")}


# ---------------- puente con el juego publicado ----------------
def read_key():
    try:
        with open(KEY_PATH, encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        return ""


def cloud_topic():
    if cfg["link"] == "code":
        return "rc_c" + cfg["code"] if cfg["code"] else ""
    return f"rc_{cfg['roblox_id']}" if cfg["roblox_id"] else ""


cloud_conn = None


def publish(key, topic, message):
    """None si Roblox lo aceptó; si no, el motivo: key (clave mala o sin permiso), http o net."""
    global cloud_conn
    body = json.dumps({"topic": topic, "message": message})
    for _ in range(2):
        try:
            if not cloud_conn:
                cloud_conn = http.client.HTTPSConnection("apis.roblox.com", timeout=5)
            cloud_conn.request("POST", f"/cloud/v2/universes/{UNIVERSE}:publishMessage", body, {"Content-Type": "application/json", "User-Agent": "RedCarpet", "x-api-key": key})
            r = cloud_conn.getresponse()
            r.read()
            return None if r.status < 300 else "key" if r.status in (401, 403) else "http"
        except (OSError, ValueError, http.client.HTTPException):
            if cloud_conn:
                cloud_conn.close()
            cloud_conn = None
    return "net"


def cloud_loop():
    """Manda la cola al servidor de Roblox. Un aviso cada 20 s para que el juego sepa que estamos.
    Roblox deja recibir (10 + 20 × jugadores) mensajes/min por tema = 30 con 1 jugador: 24/min, y cada mensaje lleva lo que quepa en 1 KB."""
    last_ping = 0.0
    while True:
        time.sleep(2.5)
        key, topic = read_key(), cloud_topic()
        if not key or not topic or time.time() - state["studio_seen"] < 3:
            state.update(cloud_ok=0.0, cloud_error="" if key else "no_key")
            with lock:
                outbox.clear()
            continue
        batch = []
        with lock:
            for ev in outbox:
                if batch and len(json.dumps({"v": 1, "e": batch + [ev]})) > 950:
                    break
                batch.append(ev)
        if not batch and time.time() - last_ping < 20:
            continue
        err = publish(key, topic, json.dumps({"v": 1, "e": batch or [{"k": "ping"}]}))
        state["cloud_error"] = err or ""
        if err:
            time.sleep(4)
            continue
        last_ping = state["cloud_ok"] = time.time()
        with lock:
            for _ in batch:
                outbox.popleft()


# ---------------- HTTP ----------------
app = Flask(__name__, static_folder=None)
app.json.sort_keys = False  # el panel enseña los elementos en el orden de DEFAULT_OV


@app.after_request
def cors(resp):  # TikTok LIVE Studio comprueba el enlace con un GET desde otro origen
    resp.headers["Access-Control-Allow-Origin"] = "*"
    return resp


@app.get("/")
def index():
    return send_from_directory(UI_DIR, "index.html")


@app.get("/ui/<path:p>")
def ui_file(p):
    return send_from_directory(UI_DIR, p)


@app.get("/o/<view>")
def overlay(view):
    return send_from_directory(UI_DIR, "overlay.html")


def lang():
    return cfg["lang"] if cfg["lang"] in OV_TEXT else "es"


def mode_label(key):
    return cfg["modes"][key]["label"] or MODE_LABEL[lang()][key]


def ov_view():
    """Los overlays con los textos vacíos rellenados con los del idioma."""
    out = copy.deepcopy(cfg["ov"])
    for els in out.values():
        for name, e in els.items():
            if not e["text"] and name in OV_TEXT[lang()]:
                e["text"] = OV_TEXT[lang()][name]
    return out


def modes_view():
    out = []
    for key, m in cfg["modes"].items():
        g = gift_catalog.get(m.get("gift", "").lower(), {})
        out.append({"key": key, "label": mode_label(key), "gift": m.get("gift", ""), "img": g.get("img", ""),
                    "coins": g.get("coins", 0), "on": m.get("on", True)})
    return out


@app.get("/api/overlay")
def api_overlay():
    now = time.time()
    with lock:
        q = queue_view()
        ds = sorted(donors.values(), key=lambda d: -d["t"])[:int(cfg["ov"]["donors"]["card"].get("max") or 20)]
    walking = state["now"] if state["now"] and now - state["now"]["t"] < 15 else None
    return jsonify({"lobby": sum(max(1, e["prio"], e["cine"]) for e in q), "prio": sum(e["prio"] for e in q),
                    "cine": sum(e["cine"] for e in q),
                    "party": max(0, round(state["party_until"] - now)), "now": walking, "queue": q[:8],
                    "donors": ds, "modes": modes_view(), "ov": ov_view(), "lang": lang(),
                    "gifts": [g for g in recent_gifts if now - g["t"] < 60]})


@app.get("/api/poll")
def api_poll():
    """Lo llama el juego cuando se juega desde Roblox Studio (cada ~0.5 s)."""
    since = request.args.get("since", -1, type=int)
    with lock:
        state["studio_seen"] = time.time()
        locked = lock_reason()
        if locked:
            out = []
        elif 0 <= since <= seq:
            out = [e for e in events if e["seq"] > since]
        else:
            out = [e for e in events if e["t"] > time.time() - 20]
        return jsonify({"seq": seq, "events": out, "live": state["status"] == "live", "locked": locked or False,
                        "sub": bool(not locked and ACC.profile.get("sub"))})


def account_view():
    return {"logged": bool(ACC.token and ACC.profile), "profile": ACC.profile, "prices": ACC.prices,
            "allowed": ACC.allowed(), "admin": ACC.is_admin(), "version": VERSION}


@app.get("/api/state")
def api_state():
    top = fame_top()
    with lock:
        q = queue_view()
        return jsonify({"fameTop": top, "status": state["status"], "error": state["error"], "lock": lock_reason(),
                        "studio": time.time() - state["studio_seen"] < 3,
                        "cloud": time.time() - state["cloud_ok"] < 30, "cloudError": state["cloud_error"],
                        "pending": len(outbox), "avatars": state["avatars"], "queue": q, "now": state["now"],
                        "party": max(0, round(state["party_until"] - time.time())), "donors": len(donors),
                        "afkLast": state["afk_last"], "overlayHost": OVERLAY_HOST, "modes": modes_view(), "hasKey": bool(read_key()),
                        "tiktok": state.get("tiktok", ""), "ovText": OV_TEXT[lang()], "modeLabel": MODE_LABEL[lang()],
                        "cfg": cfg, "log": list(log)[:80], "account": account_view(), "phone": phone_view(),
                        "auto": {"stats": cfg["auto"]["stats"], "pending": sum(e["c"] for e in auto_q),
                                 "jam": jam_pending(), "jamNext": max(0, round(state.get("jam_next", 0) - time.time()))} if ACC.is_admin() else None})


@app.get("/api/gifts")
def api_gifts():
    if request.args.get("refresh") or not gift_catalog:
        load_gift_catalog()
    return jsonify({"gifts": sorted(gift_catalog.values(), key=lambda g: (g["coins"], g["name"]))})


def clean_el(src, dst):
    for k in ("text", "font", "color", "accent"):
        if isinstance(src.get(k), str):
            dst[k] = src[k][:120]
    for k, lo, hi in (("size", 6, 400), ("x", -20, 120), ("y", -20, 120), ("every", 2, 60), ("max", 1, 50)):
        if isinstance(src.get(k), (int, float)):
            dst[k] = max(lo, min(hi, src[k]))
    if isinstance(src.get("show"), bool):
        dst["show"] = src["show"]


@app.post("/api/config")
def api_config():
    data = request.get_json(force=True)
    if "theme" in data:
        cfg["theme"] = str(data["theme"])[:30]
    if data.get("lang") in ("es", "en"):
        cfg["lang"] = data["lang"]
    if data.get("link") in ("auto", "code"):
        cfg["link"] = data["link"]
    if not premium_ok():  # AFK y ajustes del desfile son del pack (los overlays no)
        for k in ("screen", "afk", "afk_minutes", "walk_gap", "cine_gap", "fast_on", "fast_off", "fast_x"):
            data.pop(k, None)
    if data.get("screen") in ("walker", "off"):
        cfg["screen"] = data["screen"]
    if isinstance(data.get("site"), str) and ACC.is_admin():
        cfg["site"] = data["site"].strip()[:40]
        push({"k": "t", "site": cfg["site"]})
    for k in ("paused", "afk"):
        if isinstance(data.get(k), bool):
            cfg[k] = data[k]
    for k, lo, hi in (("walk_gap", 1, 60), ("cine_gap", 3, 120), ("afk_minutes", 1, 18),
                      ("fast_on", 10, 5000), ("fast_off", 0, 5000), ("fast_x", 1, 3)):
        if isinstance(data.get(k), (int, float)):
            cfg[k] = type(DEFAULT_CFG[k])(max(lo, min(hi, data[k])))  # mismo tipo que el defecto (si no, merge lo pisa)
    if data.get("afk"):
        state["afk_last"] = 0.0  # al encenderlo, un toque ya para comprobar que encuentra Roblox
    for key, m in (data.get("modes") or {}).items():
        if key in cfg["modes"] and isinstance(m, dict):
            for f in ("gift", "label"):
                if isinstance(m.get(f), str):
                    cfg["modes"][key][f] = m[f].strip()[:40]
            if isinstance(m.get("on"), bool):
                cfg["modes"][key]["on"] = m["on"]
            if key in ("party", "giant", "photo") and isinstance(m.get("seconds"), (int, float)):
                cfg["modes"][key]["seconds"] = max(3, min(300 if key == "party" else 60, int(m["seconds"])))
    for view, els in (data.get("ov") or {}).items():
        for name, e in (els or {}).items():
            if view in cfg["ov"] and name in cfg["ov"][view] and isinstance(e, dict):
                clean_el(e, cfg["ov"][view][name])
    if data.get("ovReset") in cfg["ov"]:
        cfg["ov"][data["ovReset"]] = copy.deepcopy(DEFAULT_OV[data["ovReset"]])
    fm = data.get("fame")
    if isinstance(fm, dict):
        if isinstance(fm.get("on"), bool):
            cfg["fame"]["on"] = fm["on"]
        if isinstance(fm.get("rate"), (int, float)):
            cfg["fame"]["rate"] = max(1, min(100000, int(fm["rate"])))
        if fm.get("reset"):
            with lock:
                fame.clear()
            try:
                os.remove(FAME_PATH)
            except OSError:
                pass
    if "code" in data:
        code = re.sub(r"[^A-Z0-9]", "", str(data["code"]).upper())[:6]
        if code and len(code) != 6:
            return jsonify({"ok": False, "error": "bad_code"}), 400
        cfg["code"] = code
    save_cfg()
    return jsonify({"ok": True})


@app.post("/api/queue")
def api_queue():
    """Panel: quitar, poner primero, desfilar ya, vaciar la cola."""
    d = request.get_json(force=True)
    act, name = d.get("action"), (d.get("name") or "").lower()
    e = None
    with lock:
        if act == "clear":
            for q in (cine_q, prio_q, normal_q):
                q.clear()
        hit = next(((q, i) for q in (cine_q, prio_q, normal_q) for i, x in enumerate(q) if x["n"].lower() == name), None)
        if hit and act in ("remove", "walk", "top"):
            q, i = hit
            e = q.pop(i)
            if act == "top":  # primero de todos los de rosa
                prio_q.insert(0, e)
            elif act == "walk" and e["c"] > 1:  # desfila uno ya; los demás siguen en su sitio
                q.insert(i, {**e, "c": e["c"] - 1})
    if e and act == "walk":
        walk(e, "prio" if hit[0] is prio_q else "cine" if hit[0] is cine_q else "normal")
    if act == "clear" and d.get("donors"):
        donors.clear()
    return jsonify({"ok": True})


@app.post("/api/stage")
def api_stage():
    if not premium_ok():
        return jsonify({"ok": False, "error": "premium"}), 403
    d = request.get_json(force=True)
    ev = {"k": "t"}
    if isinstance(d.get("text"), str):
        ev["text"] = d["text"][:24]
    if isinstance(d.get("color"), str) and re.match(r"^(#[0-9a-fA-F]{6}|auto)$", d["color"]):
        ev["color"] = d["color"]
    if d.get("style") in STAGE_STYLES:
        cfg["stage_style"] = ev["style"] = d["style"]
        save_cfg()
    if d.get("floor") in STAGE_FLOORS:
        cfg["stage_floor"] = ev["floor"] = d["floor"]
        save_cfg()
    if d.get("barrier") in STAGE_BARRIERS:
        cfg["stage_barrier"] = ev["barrier"] = d["barrier"]
        save_cfg()
    if d.get("marks") in STAGE_MARKS:
        cfg["stage_marks"] = ev["marks"] = d["marks"]
        save_cfg()
    if d.get("night") in STAGE_NIGHT:
        cfg["stage_night"] = ev["night"] = d["night"]
        save_cfg()
    if d.get("rot_every") in STAGE_ROT or d.get("rot_toggle") in STAGE_STYLES:
        if d.get("rot_every") in STAGE_ROT:
            cfg["rot_every"] = d["rot_every"]
        if d.get("rot_toggle") in STAGE_STYLES:
            off = set(cfg["rot_off"]) ^ {d["rot_toggle"]}
            cfg["rot_off"] = [s for s in STAGE_STYLES if s in off]
        ev["rot"] = {"every": cfg["rot_every"], "off": cfg["rot_off"]}
        save_cfg()
    push(ev)
    return jsonify({"ok": True})


@app.post("/api/roblox")
def api_roblox():
    u = (request.get_json(force=True).get("user") or "").strip().lstrip("@")
    uid = 0
    if u:
        req = urllib.request.Request("https://users.roblox.com/v1/usernames/users", json.dumps({"usernames": [u], "excludeBannedUsers": False}).encode(),
                                     {"Content-Type": "application/json", "User-Agent": "RedCarpet"})
        try:
            with urllib.request.urlopen(req, timeout=10) as r:
                found = json.loads(r.read()).get("data") or []
        except (OSError, ValueError):
            return jsonify({"ok": False, "error": "offline"}), 502
        if not found:
            return jsonify({"ok": False, "error": "roblox_not_found"}), 400
        u, uid = found[0]["name"], found[0]["id"]
    cfg["roblox_user"], cfg["roblox_id"] = u, uid
    ACC.profile.update(robloxUser=u, robloxId=uid)
    save_cfg()
    return jsonify({"ok": True, "user": u, "account": account_view()})


@app.post("/api/cloudkey")
def api_cloudkey():
    """Se guarda solo si Roblox la acepta, y nunca se devuelve al panel."""
    key = str((request.get_json(force=True) or {}).get("key", "")).strip()
    if not key:
        if os.path.exists(KEY_PATH):
            os.remove(KEY_PATH)
        return jsonify({"ok": True})
    if not re.fullmatch(r"[\x21-\x7e]{10,4000}", key):
        return jsonify({"ok": False, "error": "bad_key"}), 400
    err = publish(key, "rc_prueba", json.dumps({"v": 1, "e": [{"k": "ping"}]}))
    if err:
        return jsonify({"ok": False, "error": err}), 400
    os.makedirs(CFG_DIR, exist_ok=True)
    with open(KEY_PATH, "w", encoding="utf-8") as f:
        f.write(key)
    return jsonify({"ok": True})


@app.post("/api/connect")
def api_connect():
    user = (request.get_json(force=True).get("user") or "").strip().lstrip("@").lower()
    if not re.match(r"^[\w.]{2,24}$", user):
        return jsonify({"ok": False, "error": "bad_tiktok"}), 400
    if lock_reason():
        return jsonify({"ok": False, "error": "locked"}), 403
    cfg["tiktok_user"] = user
    save_cfg()
    connect(user)
    return jsonify({"ok": True})


@app.post("/api/disconnect")
def api_disconnect():
    disconnect()
    return jsonify({"ok": True})


@app.post("/api/test")
def api_test():
    """Prueba sin directo: un comentario con un usuario de Roblox, un regalo o el toque AFK."""
    d = request.get_json(force=True)
    if d.get("kind") == "afk":
        return jsonify({"ok": afk_nudge()})
    if lock_reason():
        return jsonify({"ok": False, "error": "locked"}), 403
    nick = (d.get("nick") or "test")[:24]
    if d.get("kind") == "gift":
        handle_gift({"uid": d.get("uid") or nick, "nick": nick, "avatar": d.get("avatar") or "",
                     "followers": int(d.get("followers") or 0), "following": int(d.get("following") or 0)},
                    d.get("gift") or "Rose", int(d.get("count") or 1), int(d.get("diamonds") or 1), test=True)
        return jsonify({"ok": True})
    if not handle_comment(nick, (d.get("name") or "").strip()):
        return jsonify({"ok": False, "error": "bad_roblox"}), 400
    return jsonify({"ok": True})


@app.post("/api/account/<what>")
def api_account_do(what):
    d = request.get_json(force=True) if request.data else {}
    if what == "login":
        r = ACC.login(d.get("username", ""), d.get("password", ""))
    elif what == "register":
        r = ACC.register(d.get("username", ""), d.get("password", ""), d.get("confirm", ""))
    elif what == "logout":
        disconnect()
        ACC.logout()
        r = {}
    elif what == "refresh":
        r = ACC.refresh()
    elif what in ("checkout", "portal", "checkout_premium"):
        r = ACC.call(what)
        if r.get("url"):
            open_url(r["url"])
    else:
        return jsonify({"error": "unknown"}), 404
    if r.get("token"):
        ACC.refresh()
    return jsonify({**account_view(), "error": r.get("error"), "url": r.get("url"), "banMsg": r.get("banMsg"), "bannedUntil": r.get("bannedUntil")})


@app.post("/api/auto")
def api_auto():
    """Eventos automáticos (solo admin): encender/apagar o lanzar uno a mano."""
    if not ACC.is_admin():
        return jsonify({"error": "forbidden"}), 403
    d = request.get_json(force=True)
    if "on" in d:
        cfg["auto"]["on"] = bool(d["on"])
        save_cfg()
        return jsonify({"ok": True})
    if lock_reason() or not game_on():
        return jsonify({"error": "no_game"}), 409
    return jsonify({"ok": True, "text": auto_event(d.get("kind") if d.get("kind") in ("racha", "party", "giant") else "racha", d.get("size") or 0, True)})


@app.post("/api/jam")
def api_jam():
    """Atasco artificial (solo admin): lanzarlo ya o cambiar la lista / el automático."""
    if not ACC.is_admin():
        return jsonify({"error": "forbidden"}), 403
    d = request.get_json(force=True)
    if isinstance(d.get("users"), list):
        cfg["jam"]["users"] = [[str(u[0]).strip().lstrip("@")[:20], str(u[1] if len(u) > 1 else "").strip().lstrip("@")[:24]]
                               for u in d["users"] if isinstance(u, list) and u and ROBLOX_NAME.match(str(u[0]).strip())][:300]
    if isinstance(d.get("auto"), bool):
        cfg["jam"]["auto"] = d["auto"]
        state["jam_next"] = time.time() + max(1, float(cfg["jam"]["every"])) * 60
    if isinstance(d.get("every"), (int, float)):
        cfg["jam"]["every"] = max(1, min(240, int(d["every"])))
    save_cfg()
    if not d.get("go"):
        return jsonify({"ok": True})
    if lock_reason() or not game_on():
        return jsonify({"error": "no_game"}), 409
    return jsonify({"ok": True, "added": jam()})


@app.post("/api/phone")
def api_phone():
    """Live Checker: crear/cambiar el código, aviso de prueba y el reinicio del LIVE (todo del Pack Premium)."""
    d = request.get_json(force=True)
    if not premium_ok() and not d.get("off"):
        return jsonify({"error": "premium", **phone_view()}), 403
    if d.get("new"):
        cfg["phone"] = "".join(secrets.choice("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") for _ in range(10))
    if d.get("off"):
        cfg["phone"] = ""
    r = d.get("restart")
    if isinstance(r, dict):
        for k in ("on", "on_warn", "on_gifts", "captcha"):
            if isinstance(r.get(k), bool):
                cfg["restart"][k] = r[k]
        if isinstance(r.get("at"), (int, float)):
            cfg["restart"]["at"] = max(1, min(239, int(r["at"])))
    save_cfg()
    if d.get("test") and cfg["phone"]:
        phone_alert("🔔 Prueba: así suenan los avisos", "danger")
    if d.get("elevate") and not studio.is_admin():  # se vuelve a abrir como administrador (un aviso de Windows)
        exe, args = (sys.executable, "") if FROZEN else (sys.executable, f'"{os.path.abspath(__file__)}"')
        if ctypes.windll.shell32.ShellExecuteW(None, "runas", exe, args, None, 1) > 32:
            disconnect()
            threading.Timer(1.0, lambda: os._exit(0)).start()
            return jsonify({"ok": True, "closing": True})
        return jsonify({"error": "denied"}), 409
    if d.get("try"):
        return jsonify({"result": restart_live(dry=True), **phone_view()})
    if d.get("now"):
        threading.Thread(target=restart_live, daemon=True).start()
    return jsonify(phone_view())


@app.post("/api/admin")
def api_admin():
    """Acciones de administrador (solo Wylo). El servidor vuelve a comprobar el rol."""
    if not ACC.is_admin():
        return jsonify({"error": "forbidden"}), 403
    d = request.get_json(force=True)
    return jsonify(ACC.call("admin_" + d.pop("action", ""), **d))


# ---------------- actualizaciones (GitHub) ----------------
RELEASES_JSON = "https://raw.githubusercontent.com/cristiancordova1207/Coreus-Games-Program-Releases/main/red-carpet.json"
_upd = {"t": 0.0, "info": None}


def _ver(v):
    return tuple(int(x) for x in re.findall(r"\d+", v or "0")[:3]) or (0,)


def latest_release():
    if time.time() - _upd["t"] < 90 and _upd["info"]:  # corto: «no se actualiza» justo después de publicar
        return _upd["info"]
    req = urllib.request.Request(RELEASES_JSON + f"?t={int(time.time() // 300)}", headers={"User-Agent": "RedCarpet"})
    with urllib.request.urlopen(req, timeout=15) as r:
        d = json.loads(r.read())
    info = {"latest": str(d.get("version", "")).lstrip("v"), "notes": d.get("notes") or "", "url": d.get("url"),
            "required": bool(d.get("required"))}
    _upd.update(t=time.time(), info=info)
    return info


_prog = {"state": "idle", "done": 0, "total": 0, "error": ""}  # barra de progreso de la actualización


def clean_env():
    """Entorno para lanzar otra copia del .exe: con las variables _PYI_* heredadas buscaría la carpeta _MEI
    de este proceso ("Failed to load Python DLL" si ya se cerró)."""
    env = {k: v for k, v in os.environ.items() if not k.startswith("_PYI") and k != "_MEIPASS2"}
    env["PYINSTALLER_RESET_ENVIRONMENT"] = "1"
    return env


def install_update(url):
    """Descarga el .exe nuevo y lo cambia por el actual cuando este se cierra."""
    import tempfile
    tmp = os.path.join(tempfile.gettempdir(), "RedCarpet-update.exe")
    req = urllib.request.Request(url, headers={"User-Agent": "RedCarpet"})
    with urllib.request.urlopen(req, timeout=300) as r, open(tmp, "wb") as f:
        _prog.update(state="downloading", done=0, total=int(r.headers.get("Content-Length") or 0), error="")
        while chunk := r.read(65536):
            f.write(chunk)
            _prog["done"] += len(chunk)
    _prog["state"] = "restarting"
    exe = sys.executable
    bat = os.path.join(tempfile.gettempdir(), "RedCarpet-update.bat")
    with open(bat, "w", encoding="utf-8") as f:
        f.write(f"""@echo off
:wait
tasklist /FI "PID eq {os.getpid()}" | find "{os.getpid()}" >nul && (timeout /t 1 /nobreak >nul & goto wait)
tasklist /FI "PID eq {os.getppid()}" | find "{os.getppid()}" >nul && (timeout /t 1 /nobreak >nul & goto wait)
set n=0
:copy
copy /y "{tmp}" "{exe}" >nul && goto run
set /a n+=1
if %n% lss 60 (timeout /t 1 /nobreak >nul & goto copy)
:run
start "" "{exe}"
del "{tmp}"
del "%~f0"
""")
    # espera al proceso y a su lanzador (PyInstaller onefile: el lanzador bloquea el .exe y mete a sus hijos
    # en un "job" que se cierra con él), por eso el .bat sale del job (CREATE_BREAKAWAY_FROM_JOB)
    env = clean_env()
    try:
        subprocess.Popen(["cmd", "/c", bat], creationflags=0x08000000 | 0x01000000, env=env)
    except OSError:
        subprocess.Popen(["cmd", "/c", bat], creationflags=0x08000000, env=env)
    threading.Timer(1.0, lambda: os._exit(0)).start()


@app.get("/api/update/progress")
def api_update_progress():
    return jsonify(_prog)


@app.route("/api/update", methods=["GET", "POST"])
def api_update():
    if os.environ.get("COREUS_PORT"):  # lo actualiza Coreus Games
        return jsonify({"available": False, "current": VERSION})
    try:
        info = latest_release()
    except Exception:
        return jsonify({"available": False, "current": VERSION})
    available = bool(info["url"]) and _ver(info["latest"]) > _ver(VERSION)
    if request.method == "POST" and available:
        if not FROZEN:
            return jsonify({"error": "dev"})
        if _prog["state"] in ("downloading", "restarting"):
            return jsonify({"ok": True})
        _prog.update(state="downloading", done=0, total=0, error="")

        def run():
            try:
                install_update(info["url"])
            except Exception as ex:
                _prog.update(state="error", error=str(ex))
        threading.Thread(target=run, daemon=True).start()
        return jsonify({"ok": True})
    info = {**info, "required": available and (info.get("required") or ACC.need_update)}  # obligatoria: sin "Más tarde"
    return jsonify({"available": available, "current": VERSION, **info})


TRIAL_TICKETS_URL = "https://discord.com/channels/1506294281801957406/1506987667408031845"
GAME_URL = "https://www.roblox.com/games/126271128517568"


@app.post("/api/open/<what>")
def api_open(what):
    url = {"trial": TRIAL_TICKETS_URL, "game": GAME_URL, "apk": APK_URL}.get(what)
    if what == "discord":
        url = "https://" + str((ACC.profile or {}).get("discord") or "discord.gg/K6TCjKAyds")
    if url:
        open_url(url)
    return jsonify({"ok": bool(url)})


def open_url(url):
    exe = browser_exe()
    if exe:
        subprocess.Popen([exe, url])
    else:
        webbrowser.open(url)


def browser_exe():
    local = os.environ.get("LOCALAPPDATA", "")
    for p in (shutil.which("chrome"),
              r"C:\Program Files\Google\Chrome\Application\chrome.exe",
              r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
              os.path.join(local, r"Google\Chrome\Application\chrome.exe"),
              shutil.which("msedge"),
              r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"):
        if p and os.path.exists(p):
            return p
    return None


def open_panel():
    url = f"http://127.0.0.1:{PORT}/"
    exe = browser_exe()
    if not exe:
        webbrowser.open(url)
        return
    subprocess.Popen([exe, f"--app={url}", "--window-size=1060,780",
                      "--user-data-dir=" + os.path.join(CFG_DIR, "browser-panel"), "--no-first-run", "--no-default-browser-check"])


def on_license_lost():
    disconnect()
    note("🔒", "warn")


def on_banned(p):
    """El admin suspendió la cuenta: se desconecta, enseña el aviso (con el motivo y hasta cuándo) y se cierra."""
    disconnect()
    msg = "Tu cuenta de Red Carpet está suspendida."
    if p.get("bannedUntil"):
        try:
            until = datetime.fromisoformat(p["bannedUntil"].replace("Z", "+00:00")).astimezone()
            msg += f"\nHasta: {until:%d/%m/%Y %H:%M}"
        except ValueError:
            pass
    if p.get("banMsg"):
        msg += f"\n\n{p['banMsg']}"
    ctypes.windll.user32.MessageBoxW(None, msg, "Red Carpet", 0x30 | 0x40000)  # aviso, siempre encima
    os._exit(0)


ACC.live_info = lambda: (state["status"] == "live", state.get("tiktok", ""), live_stats["avatars"])
ACC.live_extra = live_stats_view
ACC.on_lost = on_license_lost
ACC.on_banned = on_banned


def already_running():
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{PORT}/api/state", timeout=2):
            return True
    except Exception:
        return False


# ---------------- instalación (el .exe descargado se instala solo) ----------------
INSTALL_DIR = os.path.join(os.environ.get("LOCALAPPDATA", CFG_DIR), "Programs", "Red Carpet")
INSTALLED_EXE = os.path.join(INSTALL_DIR, "Red Carpet.exe")
UNINSTALL_KEY = r"Software\Microsoft\Windows\CurrentVersion\Uninstall\RedCarpet"


def _shortcuts():
    desktop = os.path.join(os.environ.get("USERPROFILE", ""), "Desktop")
    start = os.path.join(os.environ.get("APPDATA", ""), r"Microsoft\Windows\Start Menu\Programs")
    return [os.path.join(desktop, "Red Carpet.lnk"), os.path.join(start, "Red Carpet.lnk")]


def self_install():
    """Desde Descargas: se copia a %LOCALAPPDATA%\\Programs\\Red Carpet, crea accesos directos y se registra."""
    if not FROZEN or os.environ.get("COREUS_PORT") or os.path.normcase(os.path.abspath(sys.executable)) == os.path.normcase(INSTALLED_EXE):
        return  # Coreus Games lleva sus propias copias
    os.makedirs(INSTALL_DIR, exist_ok=True)
    try:
        shutil.copy2(sys.executable, INSTALLED_EXE)
    except PermissionError:
        pass
    ps = "; ".join(
        f"$s=(New-Object -ComObject WScript.Shell).CreateShortcut('{lnk}'); $s.TargetPath='{INSTALLED_EXE}'; "
        f"$s.WorkingDirectory='{INSTALL_DIR}'; $s.IconLocation='{INSTALLED_EXE},0'; $s.Save()" for lnk in _shortcuts())
    subprocess.run(["powershell", "-NoProfile", "-Command", ps], creationflags=0x08000000)
    try:
        import winreg
        with winreg.CreateKey(winreg.HKEY_CURRENT_USER, UNINSTALL_KEY) as k:
            for name, val in (("DisplayName", "Red Carpet"), ("DisplayVersion", VERSION), ("Publisher", "Wylo"),
                              ("DisplayIcon", INSTALLED_EXE), ("InstallLocation", INSTALL_DIR),
                              ("UninstallString", f'"{INSTALLED_EXE}" --uninstall')):
                winreg.SetValueEx(k, name, 0, winreg.REG_SZ, val)
            winreg.SetValueEx(k, "NoModify", 0, winreg.REG_DWORD, 1)
    except OSError:
        pass
    subprocess.Popen([INSTALLED_EXE], env=clean_env())
    sys.exit(0)


def uninstall():
    for lnk in _shortcuts():
        try:
            os.remove(lnk)
        except OSError:
            pass
    try:
        import winreg
        winreg.DeleteKey(winreg.HKEY_CURRENT_USER, UNINSTALL_KEY)
    except OSError:
        pass
    subprocess.Popen(["cmd", "/c", f'timeout /t 2 /nobreak >nul & rmdir /s /q "{INSTALL_DIR}"'], creationflags=0x08000000)
    sys.exit(0)


if __name__ == "__main__":
    if "--uninstall" in sys.argv:
        uninstall()
    self_install()
    if already_running():
        open_panel()
        sys.exit(0)
    ACC.profile.update(robloxUser=cfg["roblox_user"], robloxId=cfg["roblox_id"])
    for fn in (cloud_loop, walk_loop, afk_loop, auto_loop, load_gift_catalog, phone_loop, studio_loop):
        threading.Thread(target=fn, daemon=True).start()
    if "--no-window" not in sys.argv:
        threading.Timer(1.0, open_panel).start()
    print(f"Red Carpet en http://127.0.0.1:{PORT}")
    app.run(host="127.0.0.1", port=PORT, threaded=True)
