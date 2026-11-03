"""Compila Red Carpet a un solo .exe:  py -3.13 tools/build.py   ->  dist/Red-Carpet.exe"""
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
from red_carpet import VERSION  # noqa: E402


def main():
    build = os.path.join(ROOT, "build")
    shutil.rmtree(build, ignore_errors=True)
    os.makedirs(build)
    v = VERSION.replace(".", ",")
    with open(os.path.join(build, "version.txt"), "w") as f:
        f.write(f"""VSVersionInfo(ffi=FixedFileInfo(filevers=({v},0), prodvers=({v},0)),
kids=[StringFileInfo([StringTable('040904B0', [StringStruct('CompanyName', 'Wylo'), StringStruct('FileDescription', 'Red Carpet'),
StringStruct('FileVersion', '{VERSION}'), StringStruct('ProductName', 'Red Carpet'), StringStruct('ProductVersion', '{VERSION}')])]),
VarFileInfo([VarStruct('Translation', [1033, 1200])])])""")
    cmd = [sys.executable, "-m", "PyInstaller", "--noconfirm", "--onefile", "--noconsole", "--name", "Red-Carpet",
           "--icon", os.path.join(ROOT, "assets", "redcarpet.ico"), "--version-file", os.path.join(build, "version.txt"),
           "--add-data", os.path.join(ROOT, "ui") + ";ui", "--collect-all", "TikTokLive", "--collect-all", "winrt", "--copy-metadata", "betterproto",
           "--workpath", os.path.join(build, "pyi"), "--specpath", build, "--distpath", os.path.join(ROOT, "dist"),
           os.path.join(ROOT, "red_carpet.py")]
    subprocess.run(cmd, check=True)
    exe = os.path.join(ROOT, "dist", "Red-Carpet.exe")
    print(f"\nListo: {exe}  ({os.path.getsize(exe) / 1e6:.1f} MB)  v{VERSION}")


if __name__ == "__main__":
    main()
