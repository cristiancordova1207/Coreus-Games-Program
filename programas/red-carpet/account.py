"""Red Carpet no tiene cuentas: esto responde como una licencia siempre válida."""


class Account:
    def __init__(self, cfg_dir, version):
        self.version = version
        self.token = "local"
        self.profile = {"username": "Red Carpet", "role": "user", "plan": "lifetime", "allowed": True, "premium": True, "sub": True,
                        "tiktoks": None, "robloxUser": "", "robloxId": 0}
        self.prices = None
        self.need_update = False

    def call(self, action, timeout=20, **data):
        return {}

    def _take(self, r):
        return r

    def login(self, *a):
        return {}

    register = login

    def logout(self):
        pass

    def refresh(self):
        return {}

    def allowed(self):
        return True

    def is_admin(self):
        return False

    def beat_now(self):
        pass
