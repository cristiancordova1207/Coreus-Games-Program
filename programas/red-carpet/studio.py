"""TikTok LIVE Studio visto desde fuera: captura + OCR de Windows (es-MX) para leer el contador del LIVE, ver avisos
(directo restringido, verificación/captcha) y reiniciar el directo como en el vídeo del usuario:
contador → Finalizar LIVE → Finalizar ahora → cerrar resumen → título → Aviso sobre el contenido: Marca propia → Guardar → Iniciar LIVE.
LIVE Studio corre como administrador: para hacer clic en él este programa también tiene que estarlo (si no, Windows ignora los clics).
"""
import asyncio
import ctypes
import difflib
import ctypes.wintypes as wt
import re
import time
import unicodedata

from PIL import ImageGrab

u32 = ctypes.windll.user32
TITLE = "TikTok LIVE Studio"
TIMER = re.compile(r"^(\d{1,2}):(\d{2}):(\d{2})$")
# avisos que se mandan al móvil (sin tildes, en minúsculas). Sólo se miran en el centro de la ventana: el chat queda fuera.
ALERT_WORDS = ("restringid", "restriccion", "visibilidad", "verifica", "captcha", "rompecabezas", "desliza", "suspendid",
               "infraccion", "infringe", "advertencia", "violacion", "prohibid", "bloquead")


def norm(s):
    return "".join(c for c in unicodedata.normalize("NFD", s.lower()) if unicodedata.category(c) != "Mn")


def is_admin():
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except OSError:
        return False


def dpi_aware():
    u32.SetThreadDpiAwarenessContext(ctypes.c_void_p(-4))  # por hilo: coordenadas reales en pantallas con zoom


def window():
    """La ventana principal de LIVE Studio (la más grande con ese título)."""
    found = []

    @ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)
    def cb(h, _):
        buf = ctypes.create_unicode_buffer(64)
        u32.GetWindowTextW(h, buf, 64)
        if buf.value == TITLE and u32.IsWindowVisible(h):
            r = rect(h)
            found.append(((r[2] - r[0]) * (r[3] - r[1]), h))
        return True
    u32.EnumWindows(cb, 0)
    return max(found)[1] if found else None


def monitor(h):
    """Rectángulo (en píxeles reales) de la pantalla donde está la ventana h."""
    class MI(ctypes.Structure):
        _fields_ = [("cb", wt.DWORD), ("rc", wt.RECT), ("work", wt.RECT), ("flags", wt.DWORD)]
    mi = MI(cb=ctypes.sizeof(MI))
    u32.MonitorFromWindow.restype = wt.HMONITOR  # puntero: que no se corte en 64 bits
    u32.GetMonitorInfoW(wt.HMONITOR(u32.MonitorFromWindow(wt.HWND(h), 2)), ctypes.byref(mi))  # 2 = la más cercana
    return mi.rc.left, mi.rc.top, mi.rc.right, mi.rc.bottom


def rect(h):
    """Rectángulo visible (sin el borde invisible de las ventanas maximizadas)."""
    r = wt.RECT()
    if ctypes.windll.dwmapi.DwmGetWindowAttribute(h, 9, ctypes.byref(r), ctypes.sizeof(r)):  # DWMWA_EXTENDED_FRAME_BOUNDS
        u32.GetWindowRect(h, ctypes.byref(r))
    return r.left, r.top, r.right, r.bottom


def on_top(h):
    """¿Se ve? (no minimizada y sin otra ventana encima en el centro ni en la barra de abajo)."""
    if u32.IsIconic(h):
        return False
    x0, y0, x1, y1 = rect(h)
    for fx, fy in ((0.5, 0.5), (0.5, 0.9), (0.3, 0.3), (0.7, 0.3)):
        p = wt.POINT(int(x0 + (x1 - x0) * fx), int(y0 + (y1 - y0) * fy))
        w = u32.WindowFromPoint(p)
        if u32.GetAncestor(w, 2) != h:  # GA_ROOT
            return False
    return True


def grab(h):
    x0, y0, x1, y1 = rect(h)
    return ImageGrab.grab(bbox=(x0, y0, x1, y1), all_screens=True), (x0, y0)


async def _ocr(img, lang=None):
    from winrt.windows.globalization import Language
    from winrt.windows.graphics.imaging import BitmapAlphaMode, BitmapPixelFormat, SoftwareBitmap
    from winrt.windows.media.ocr import OcrEngine
    from winrt.windows.storage.streams import DataWriter
    eng = None
    for tag in ((lang,) if lang else ("es-MX", "es-ES")):
        if OcrEngine.is_language_supported(Language(tag)):
            eng = OcrEngine.try_create_from_language(Language(tag))
            break
    eng = eng or OcrEngine.try_create_from_user_profile_languages()
    img = img.convert("RGBA")
    dw = DataWriter()
    dw.write_bytes(img.tobytes("raw", "BGRA"))
    bmp = SoftwareBitmap.create_copy_from_buffer(dw.detach_buffer(), BitmapPixelFormat.BGRA8, img.width, img.height,
                                                 BitmapAlphaMode.PREMULTIPLIED)
    return await eng.recognize_async(bmp)


def ocr(img, k=2, lang=None):
    """[{t: texto, n: normalizado, x, y (centro), x0, y0, x1, y1}] en coordenadas de la imagen.
    Se lee al doble de tamaño: la letra pequeña de LIVE Studio (el contador, el menú) sale mucho mejor."""
    out = []
    for ln in asyncio.run(_ocr(img.resize((img.width * k, img.height * k)), lang)).lines:
        bs = [w.bounding_rect for w in ln.words]
        x0, y0 = min(b.x for b in bs) / k, min(b.y for b in bs) / k
        x1, y1 = max(b.x + b.width for b in bs) / k, max(b.y + b.height for b in bs) / k
        out.append({"t": ln.text, "n": norm(ln.text), "x": (x0 + x1) / 2, "y": (y0 + y1) / 2, "x0": x0, "y0": y0, "x1": x1, "y1": y1})
    return out


def has(needle, text):
    """¿needle está en text? Con tolerancia a fallos del OCR ("Finahzar UVE" = "finalizar live")."""
    if needle in text:
        return True
    n = len(needle)
    return n >= 6 and any(difflib.SequenceMatcher(None, needle, text[i:i + n]).ratio() >= 0.86 for i in range(max(1, len(text) - n + 1)))


def find(lines, *needles, box=(0, 0, 1, 1), size=None):
    """Primera línea que contiene alguno de los textos, dentro de box (fracciones de la ventana)."""
    W, H = size
    for ln in lines:
        if box[0] * W <= ln["x"] <= box[2] * W and box[1] * H <= ln["y"] <= box[3] * H and any(has(n, ln["n"]) for n in needles):
            return ln
    return None


def timer_lines(img):
    """El contador (00:00:18) sólo lo lee el OCR en inglés y recortado: líneas de la barra de abajo en coordenadas de la ventana."""
    W, H = img.size
    x0, y0 = int(W * 0.45), int(H * 0.85)
    out = []
    for ln in ocr(img.crop((x0, y0, int(W * 0.9), H)), 3, "en-US"):
        if TIMER.match(ln["t"].replace(" ", "")):
            for k in ("x", "x0", "x1"):
                ln[k] += x0
            for k in ("y", "y0", "y1"):
                ln[k] += y0
            out.append(ln)
    return out


def read_timer(lines, size):
    """Segundos que lleva el LIVE según el contador de abajo (None si no está en directo o no se ve)."""
    W, H = size
    for ln in lines:
        m = TIMER.match(ln["t"].replace(" ", "").replace(".", ":").translate(str.maketrans("OoIl", "0011")))
        if m and ln["y"] > H * 0.75 and W * 0.25 < ln["x"] < W * 0.85:
            return int(m[1]) * 3600 + int(m[2]) * 60 + int(m[3]), ln
    return None


def _center(ln, size):
    W, H = size
    return W * 0.18 < ln["x"] < W * 0.8 and H * 0.05 < ln["y"] < H * 0.92


def alerts(lines, size):
    """Textos de aviso que se ven en el centro (ventanas emergentes de TikTok)."""
    return [ln["t"] for ln in lines if _center(ln, size) and any(k in ln["n"] for k in ALERT_WORDS)
            and "desbloque" not in ln["n"]]  # «Recompensa desbloqueada» del resumen no es un aviso


# captcha de inactividad (textos sacados de LIVE Studio, locales/Live_Studio/es-419.json): «El LIVE terminará en: 04:49»,
# «Hemos detectado inactividad...», «Selecciona 2 objetos de la misma forma». Hay 5 min para resolverlo.
CAPTCHA = ("el live terminara en", "detectado inactividad", "completa la verificacion", "objetos de la misma forma")


def captcha(lines, size):
    """¿Está el captcha de inactividad en el centro de la ventana?"""
    return any(_center(ln, size) and any(has(k, ln["n"]) for k in CAPTCHA) for ln in lines)


GIFTS_OFF = ("suspend", "desactiv", "deshabilit", "no disponible", "no estan disponibles", "no se pueden enviar", "restringid", "pausad")


def gifts_off(lines, size):
    """Aviso de que los regalos se desactivaron (una línea que habla de regalos y de desactivarlos)."""
    return [ln["t"] for ln in lines if _center(ln, size) and "regalo" in ln["n"] and any(k in ln["n"] for k in GIFTS_OFF)]


DISMISS = ("entendido", "aceptar", "de acuerdo", "cerrar", "vale", "ok", "lo tengo", "confirmar")


def dismiss(log):
    """Cierra la ventana de aviso de LIVE Studio: su botón (Entendido/Aceptar/Cerrar…) o, si no lo hay, Esc."""
    dpi_aware()
    h = window()
    if not h:
        return False
    focus(h)
    time.sleep(0.5)
    img, org = grab(h)
    lines = ocr(img)
    btn = next((ln for ln in lines if _center(ln, img.size) and ln["n"].strip(" .!") in DISMISS), None)
    if btn:
        click(org[0] + btn["x"], org[1] + btn["y"])
        log(f"🧹 Aviso cerrado («{btn['t']}»)")
    else:
        key(0x1B)
        log("🧹 Aviso cerrado (Esc)")
    time.sleep(0.6)
    return True


def find_x(img):
    """La X de cerrar un panel buscada por su forma (el OCR no siempre la lee): una mancha clara pequeña y cuadrada,
    sola en su fila, con las dos diagonales encendidas y el centro de los bordes apagado. La más a la derecha y arriba."""
    import numpy as np
    W, H = img.size
    rx0, ry0, rx1, ry1 = int(W * 0.3), int(H * 0.06), int(W * 0.85), int(H * 0.35)
    g = np.asarray(img.crop((rx0, ry0, rx1, ry1)).convert("L")) > 140
    h, w = g.shape
    seen = np.zeros_like(g)
    comps = []
    ys, xs = np.nonzero(g)
    for sy, sx in zip(ys, xs):
        if seen[sy, sx]:
            continue
        stack, pts = [(sy, sx)], []
        seen[sy, sx] = True
        while stack:
            y, x = stack.pop()
            pts.append((y, x))
            if len(pts) > 600:  # demasiado grande para ser una X
                break
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < h and 0 <= nx < w and g[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
        p = np.array(pts)
        comps.append((p[:, 0].min(), p[:, 1].min(), p[:, 0].max(), p[:, 1].max(), len(pts)))

    def lit(y, x):
        return g[max(0, y - 1):y + 2, max(0, x - 1):x + 2].any()

    out = []
    for c in comps:
        y0, x0, y1, x1, n = c
        bw, bh = x1 - x0 + 1, y1 - y0 + 1
        if not (5 <= bw <= 24 and 5 <= bh <= 24 and 0.75 <= bw / bh <= 1.33 and n < bw * bh * 0.55):
            continue
        k = 9
        d1 = sum(lit(y0 + round(i * (bh - 1) / (k - 1)), x0 + round(i * (bw - 1) / (k - 1))) for i in range(k))
        d2 = sum(lit(y0 + round(i * (bh - 1) / (k - 1)), x1 - round(i * (bw - 1) / (k - 1))) for i in range(k))
        if d1 < k - 1 or d2 < k - 1:
            continue
        my, mx = (y0 + y1) // 2, (x0 + x1) // 2
        if g[y0, mx] or g[y1, mx] or g[my, x0] or g[my, x1]:  # bordes: en una X están vacíos
            continue
        # sola en su fila (una letra «x» dentro de una palabra tiene vecinas)
        if any(o is not c and abs((o[0] + o[2]) / 2 - my) < bh and (abs(o[1] - x1) < 14 or abs(x0 - o[3]) < 14) for o in comps):
            continue
        out.append({"t": "x", "n": "x", "x": int(rx0 + mx), "y": int(ry0 + my), "x0": int(rx0 + x0), "y0": int(ry0 + y0), "x1": int(rx0 + x1), "y1": int(ry0 + y1)})
    return max(out, key=lambda ln: ln["x"] - ln["y"], default=None)


def look():
    """(lines, size) de LIVE Studio si se ve; None si no está abierto o lo tapa otra ventana."""
    dpi_aware()
    h = window()
    if not h or not on_top(h):
        return None
    img, _ = grab(h)
    return ocr(img) + timer_lines(img), img.size


# ---------------- ratón y teclado ----------------
class _MI(ctypes.Structure):
    _fields_ = [("dx", wt.LONG), ("dy", wt.LONG), ("mouseData", wt.DWORD), ("dwFlags", wt.DWORD), ("time", wt.DWORD),
                ("dwExtraInfo", ctypes.c_size_t)]


class _IN(ctypes.Structure):
    class _U(ctypes.Union):
        _fields_ = [("mi", _MI), ("pad", ctypes.c_byte * 32)]
    _anonymous_ = ("u",)
    _fields_ = [("type", wt.DWORD), ("u", _U)]


def _mouse(flags, data=0):
    i = _IN(type=0, mi=_MI(0, 0, ctypes.c_ulong(data & 0xFFFFFFFF).value, flags, 0, 0))
    u32.SendInput(1, ctypes.byref(i), ctypes.sizeof(_IN))


def click(x, y):
    u32.SetCursorPos(int(x), int(y))
    time.sleep(0.08)
    _mouse(0x0002)  # izquierdo abajo
    time.sleep(0.05)
    _mouse(0x0004)  # arriba


def wheel(x, y, notches):
    u32.SetCursorPos(int(x), int(y))
    for _ in range(abs(notches)):
        _mouse(0x0800, -120 if notches > 0 else 120)  # positivo = bajar
        time.sleep(0.03)


def key(vk):
    u32.keybd_event(vk, 0, 0, 0)
    u32.keybd_event(vk, 0, 2, 0)


def focus(h):
    if u32.IsIconic(h):
        u32.ShowWindow(h, 9)  # SW_RESTORE
    key(0x12)  # un Alt "suelta" el bloqueo de Windows a SetForegroundWindow
    u32.SetForegroundWindow(h)


# ---------------- reinicio del LIVE ----------------
class Step(Exception):
    pass


SUMMARY = ("duracion:", "total visualizaciones", "espectadores se ha")  # resumen al terminar (el titular cambia)


class Blocked(Step):
    """Algo tapaba la pantalla y se cerró: hay que repetir la acción."""


class Studio:
    """Reinicio del LIVE mirando la pantalla: cada acción se comprueba con capturas seguidas; si algo la tapa
    (resumen, aviso de TikTok, ventana con Aceptar/Cerrar…) se cierra y la acción se repite hasta lograrlo."""

    def __init__(self, log):
        self.log, self.h = log, window()
        if not self.h:
            raise Step("no está abierto TikTok LIVE Studio")
        self.esc_summary = False
        self.need = ()  # paneles que el objetivo necesita ahora (títulos): esos nunca se cierran

    def shot(self):
        for i in range(10):  # falla un momento con el aviso de Windows (UAC) o al bloquear la pantalla
            try:
                img, self.org = grab(self.h)
                break
            except OSError:
                if i == 9:
                    raise
                time.sleep(1)
        self.img, self.size = img, img.size
        self.lines = ocr(img) + timer_lines(img)
        return self.lines

    def unblock(self):
        """Mira la última captura y cierra lo que tape la pantalla. True si cerró algo."""
        if find(self.lines, *SUMMARY, box=(0.15, 0.05, 0.85, 0.5), size=self.size):
            c = find(self.lines, "centro live", box=(0.15, 0.06, 0.85, 0.2), size=self.size)
            if self.esc_summary and c:  # Esc no bastó: la X (a la derecha de "Centro LIVE" del resumen)
                click(self.org[0] + c["x1"] + self.size[0] * 0.024, self.org[1] + c["y"])
            else:
                key(0x1B)
            self.esc_summary = not self.esc_summary
            self.log("🧹 Resumen del LIVE cerrado")
        else:
            btn = next((ln for ln in self.lines if _center(ln, self.size) and ln["n"].strip(" .!") in DISMISS), None)
            warn = alerts(self.lines, self.size)
            if btn:
                self.at(btn)
                self.log(f"🧹 Ventana cerrada («{btn['t']}»)" + (f": {' '.join(warn)[:80]}" if warn else ""))
            elif warn:
                key(0x1B)
                self.log(f"🧹 Aviso cerrado (Esc): {' '.join(warn)[:80]}")
            elif not (self.need and find(self.lines, *self.need, size=self.size)) and (x := self.close_x()):
                self.at(x)
                self.log("🧹 Panel cerrado (X)")
            else:
                return False
        time.sleep(0.7)
        return True

    def close_x(self):
        """La X de un panel abierto en medio de la pantalla (la de la ventana, arriba del todo, no cuenta)."""
        W, H = self.size
        return next((ln for ln in self.lines if ln["n"].strip() in ("x", "×") and W * 0.3 < ln["x"] < W * 0.85
                     and H * 0.06 < ln["y"] < H * 0.35), None) or find_x(self.img)

    def wait(self, *needles, box=(0, 0, 1, 1), secs=6.0, gone=False, test=None, retry=False):
        """Captura tras captura hasta ver lo que busca (o que desaparezca). Lo que tape la pantalla se cierra por el
        camino; con retry=True eso corta la espera (Blocked) para que do() repita la acción."""
        test = test or (lambda: find(self.lines, *needles, box=box, size=self.size))
        end = time.time() + secs
        while True:
            self.shot()
            ln = test()
            if (not ln) == gone:
                return ln or True
            if self.unblock():
                if retry:
                    raise Blocked("algo tapaba la pantalla")
                end += 1.5
            elif time.time() > end:
                raise Step(("sigue: " if gone else "no aparece: ") + " / ".join(needles or ("contador",)))
            time.sleep(0.25)

    def do(self, action, *needles, tries=4, secs=4.0, **kw):
        """action() y comprobar el resultado en pantalla; si no sale (o algo lo tapaba) se repite."""
        for i in range(tries):
            if action() is False:  # no se pudo ni intentar (no se ve el botón): mirar otra vez
                self.shot()
                self.unblock()
                time.sleep(0.5)
                continue
            try:
                return self.wait(*needles, secs=secs, retry=True, **kw)
            except Step as ex:
                if i == tries - 1:
                    raise
                self.log(f"↻ Otra vez ({ex})")
        raise Step("no se pudo: " + " / ".join(needles or ("acción",)))

    def at(self, ln, dx=0.0):
        """Clic en el centro de una línea (dx = desplazamiento en fracción del ancho)."""
        click(self.org[0] + ln["x"] + dx * self.size[0], self.org[1] + ln["y"])

    def clean(self, secs=8.0):
        """Cierra todo lo que tape la pantalla (resumen, avisos) hasta que quede limpia."""
        end = time.time() + secs
        while time.time() < end:
            self.shot()
            if not self.unblock():
                return
        raise Step("no consigo cerrar lo que tapa la pantalla")

    def run(self, dry=False):
        t0 = time.time()
        dpi_aware()
        focus(self.h)
        time.sleep(0.6)
        self.clean()
        tm = read_timer(self.lines, self.size)
        if not tm:
            raise Step("no se ve el contador del LIVE")
        box = (0.3, 0.6, 0.9, 1)

        def open_menu():  # el contador abre el menú Finalizar / Pausar (si ya está abierto, no se toca)
            if find(self.lines, "finalizar live", "pausar live", box=box, size=self.size):
                return
            t = read_timer(self.lines, self.size)
            self.at(t[1] if t else tm[1])

        menu = self.do(open_menu, "finalizar live", "pausar live", box=box)
        if dry:
            key(0x1B)  # Esc: cierra el menú sin terminar nada
            self.log(f"🧪 Prueba OK: contador {tm[1]['t']} y menú «Finalizar LIVE» encontrados")
            return time.time() - t0

        self.need = ("finalizar live", "pausar live", "finalizar ahora")  # menú y confirmación de Finalizar

        def end_live():
            m = find(self.lines, "finalizar live", "pausar live", box=box, size=self.size)
            if not m:  # el menú se cerró: abrirlo otra vez
                open_menu()
                time.sleep(0.6)
                m = find(self.shot(), "finalizar live", "pausar live", box=box, size=self.size)
                if not m:
                    return False
            if "pausar" in m["n"]:  # el OCR a veces lee «Finahzar»: Finalizar está justo encima de Pausar
                m = dict(m, y=m["y"] - self.size[1] * 0.039)
            self.at(m)

        self.do(end_live, "finalizar ahora")

        def confirm():
            b = find(self.lines, "finalizar ahora", size=self.size)
            return self.at(b) if b else False

        self.do(confirm, test=lambda: not find(self.lines, "finalizar ahora", size=self.size)
                and not read_timer(self.lines, self.size))
        self.need = ()
        self.log("⏹️ LIVE terminado: preparando el nuevo")
        return self.start(tm[1], t0)

    def start(self, tm_ln=None, t0=None):
        """Segunda mitad: con el LIVE ya terminado, cierra el resumen, pone «Marca propia» e inicia el LIVE."""
        t0 = t0 or time.time()
        if tm_ln is None:  # se llama sola: poner LIVE Studio delante
            dpi_aware()
            focus(self.h)
            time.sleep(0.6)
        try:  # el resumen tarda un poco en salir
            self.wait(*SUMMARY, box=(0.15, 0.05, 0.85, 0.5), secs=6)
        except Step:
            pass
        self.need = ("ajustes de live",)  # el panel de Marca propia: hace falta hasta Guardar
        self.clean()

        def title():  # título del directo (arriba en el centro) → Ajustes de LIVE
            if find(self.lines, "ajustes de live", size=self.size):
                return
            t = next((ln for ln in self.lines if ln["y"] < self.size[1] * 0.04 and self.size[0] * 0.3 < ln["x"] < self.size[0] * 0.7
                      and "tiktok live" not in ln["n"]), None)
            return self.at(t) if t else False

        hdr = self.do(title, "ajustes de live")
        # bajar hasta "Aviso sobre el contenido"
        aviso = None
        for _ in range(8):
            wheel(self.org[0] + hdr["x"] + self.size[0] * 0.08, self.org[1] + self.size[1] * 0.5, 5)
            time.sleep(0.35)
            aviso = find(self.shot(), "aviso sobre el contenido", size=self.size)
            if aviso and aviso["y"] < self.size[1] * 0.75:
                break
            if self.unblock():
                hdr = self.do(title, "ajustes de live")
        if not aviso:
            raise Step("no aparece «Aviso sobre el contenido»")

        def below():
            return 0.2, (aviso["y"] + 4) / self.size[1], 0.8, (aviso["y"] + self.size[1] * 0.12) / self.size[1]

        if find(self.lines, "marca propia", box=below(), size=self.size):
            self.log("🏷️ «Marca propia» ya estaba puesta")
        else:
            def dropdown():
                sel = find(self.lines, "selecciona", "desactivado", box=below(), size=self.size)
                if sel:
                    self.at(sel)
                else:  # el desplegable está debajo del texto explicativo
                    click(self.org[0] + aviso["x0"] + self.size[0] * 0.05, self.org[1] + aviso["y"] + self.size[1] * 0.075)

            self.at(self.do(dropdown, "marca propia"))
            time.sleep(0.3)
            self.at(hdr)  # clic en la cabecera del panel: cierra el desplegable
            time.sleep(0.4)
            if not find(self.shot(), "marca propia", box=below(), size=self.size):
                raise Step("«Marca propia» no se quedó puesta")
            self.log("🏷️ «Marca propia» activada")

        def save():
            g = find(self.lines, "guardar", box=(0.2, 0.5, 0.8, 1), size=self.size)
            return self.at(g) if g else False

        self.do(save, "ajustes de live", gone=True)
        self.need = ()

        def go():
            b = find(self.lines, "iniciar live", box=(0.3, 0.75, 0.9, 1), size=self.size)
            if b:
                self.at(b)
            elif tm_ln:  # blanco sobre rosa: a veces el OCR no lo lee. Está donde estaba el contador
                self.at(tm_ln)
            else:
                return False

        self.shot()
        self.do(go, test=lambda: read_timer(self.lines, self.size), secs=8)
        self.log(f"🔴 LIVE nuevo en marcha ({time.time() - t0:.0f} s)")
        return time.time() - t0

    def favorite(self):
        """Herramientas → Favorito del público: si sale el botón de empezar, lo pulsa; con «Finalizar ahora» ya está activo."""
        dpi_aware()
        focus(self.h)
        time.sleep(0.5)
        self.shot()
        self.need = ("favorito del publico", "historial")
        tool = find(self.lines, "favorito del", box=(0, 0.3, 0.25, 1), size=self.size)
        if not tool:
            raise Step("no encuentro «Favorito del público» en Herramientas")
        self.at(tool)
        self.wait("favorito del publico (", "ajustes", box=(0.12, 0, 0.6, 0.3))
        time.sleep(0.4)
        self.shot()
        box = (0.12, 0.3, 0.6, 1)
        if find(self.lines, "finalizar ahora", box=box, size=self.size):
            self.log("💝 Favorito del público ya estaba activo")
        else:
            go = find(self.lines, "iniciar", "empezar", "comenzar", "activar", "publicar", box=box, size=self.size)
            if not go:
                raise Step("no encuentro el botón para iniciar Favorito del público")
            self.at(go)
            try:  # al empezar, el panel a veces se cierra solo y sale el overlay: también vale
                self.wait("finalizar ahora", box=box, secs=6)
            except Step:
                if find(self.shot(), "iniciar", "empezar", "comenzar", "activar", "publicar", box=box, size=self.size):
                    raise Step("Favorito del público no empezó")
            self.log("💝 Favorito del público activado")
        key(0x1B)  # cerrar el panel
        time.sleep(0.4)
        if find(self.shot(), "historial", box=(0.12, 0, 0.6, 0.2), size=self.size):
            self.at(tool)  # el botón de la herramienta también lo cierra
