#!/usr/bin/env python3
"""
install.py — Crée un environnement virtuel dédié à WatchFox, y installe les
dépendances, puis crée un raccourci bureau qui lance l'application avec ce
même venv (pas avec le Python système).

Usage :
    python3 install.py

Peut être relancé sans risque : si le venv existe déjà, il est réutilisé.
"""

import os
import platform
import subprocess
import sys

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
MAIN_SCRIPT = os.path.join(PROJECT_DIR, "main.py")
VENV_DIR = os.path.join(PROJECT_DIR, "venv")
APP_NAME = "WatchFox"

# ── Adapte cette liste si requirements.txt n'existe pas ──────────────────
FALLBACK_REQUIREMENTS = [
    "phonenumbers",
    "Pillow",
    # ajoute ici les autres dépendances de tes modules (requests, etc.)
]


def get_venv_python():
    """Retourne le chemin de l'interpréteur Python à l'intérieur du venv."""
    if platform.system() == "Windows":
        return os.path.join(VENV_DIR, "Scripts", "python.exe")
    return os.path.join(VENV_DIR, "bin", "python")


def get_venv_pythonw():
    """Sous Windows, pythonw.exe évite l'ouverture d'une console noire.
    Retourne None si absent (Linux/macOS, ou si non généré par le venv)."""
    if platform.system() == "Windows":
        candidate = os.path.join(VENV_DIR, "Scripts", "pythonw.exe")
        return candidate if os.path.isfile(candidate) else None
    return None


def create_venv():
    if os.path.isdir(VENV_DIR):
        print(f"[i] Environnement virtuel déjà présent : {VENV_DIR}")
        return
    print(f"[*] Création de l'environnement virtuel dans : {VENV_DIR}")
    try:
        subprocess.check_call([sys.executable, "-m", "venv", VENV_DIR])
        print("[+] Environnement virtuel créé.")
    except subprocess.CalledProcessError as e:
        print(f"[!] Impossible de créer le venv : {e}")
        sys.exit(1)


def install_dependencies():
    venv_python = get_venv_python()
    if not os.path.isfile(venv_python):
        print(f"[!] Interpréteur introuvable dans le venv : {venv_python}")
        sys.exit(1)

    print("[*] Mise à jour de pip dans le venv...")
    subprocess.check_call([venv_python, "-m", "pip", "install", "--upgrade", "pip"])

    print("[*] Installation des dépendances dans le venv...")
    req_file = os.path.join(PROJECT_DIR, "requirements.txt")

    if os.path.isfile(req_file):
        print("[i] requirements.txt trouvé, installation depuis ce fichier.")
        cmd = [venv_python, "-m", "pip", "install", "-r", req_file]
    else:
        print("[i] Aucun requirements.txt trouvé, utilisation de la liste par défaut.")
        cmd = [venv_python, "-m", "pip", "install"] + FALLBACK_REQUIREMENTS

    try:
        subprocess.check_call(cmd)
        print("[+] Dépendances installées avec succès dans le venv.")
    except subprocess.CalledProcessError as e:
        print(f"[!] Erreur lors de l'installation : {e}")
        sys.exit(1)


def create_shortcut_linux():
    home = os.path.expanduser("~")
    desktop_dir = os.path.join(home, "Desktop")
    if not os.path.isdir(desktop_dir):
        desktop_dir = os.path.join(home, "Bureau")  # locale FR
    os.makedirs(desktop_dir, exist_ok=True)

    shortcut_path = os.path.join(desktop_dir, f"{APP_NAME}.desktop")
    venv_python = get_venv_python()
    icon_path = os.path.join(PROJECT_DIR, "icon.png")
    icon_line = f"Icon={icon_path}\n" if os.path.isfile(icon_path) else ""

    content = (
        "[Desktop Entry]\n"
        "Version=1.0\n"
        "Type=Application\n"
        f"Name={APP_NAME}\n"
        "Comment=Intelligence & Investigation Framework\n"
        f'Exec={venv_python} "{MAIN_SCRIPT}"\n'
        f"Path={PROJECT_DIR}\n"
        "Terminal=false\n"
        f"{icon_line}"
        "Categories=Utility;\n"
    )

    with open(shortcut_path, "w") as f:
        f.write(content)
    os.chmod(shortcut_path, 0o755)

    print(f"[+] Raccourci créé : {shortcut_path}")
    print("[i] Selon ton environnement de bureau (GNOME/KDE...), il peut être "
          "nécessaire de faire un clic droit sur le raccourci puis "
          "'Autoriser le lancement' / 'Faire confiance' la première fois.")


def create_shortcut_windows():
    desktop_dir = os.path.join(os.path.expanduser("~"), "Desktop")
    # Préfère pythonw.exe (pas de console noire) si dispo, sinon python.exe
    venv_exec = get_venv_pythonw() or get_venv_python()

    try:
        from win32com.client import Dispatch  # nécessite pywin32

        shortcut_path = os.path.join(desktop_dir, f"{APP_NAME}.lnk")
        shell = Dispatch("WScript.Shell")
        shortcut = shell.CreateShortCut(shortcut_path)
        shortcut.Targetpath = venv_exec
        shortcut.Arguments = f'"{MAIN_SCRIPT}"'
        shortcut.WorkingDirectory = PROJECT_DIR

        icon_path = os.path.join(PROJECT_DIR, "icon.ico")
        if os.path.isfile(icon_path):
            shortcut.IconLocation = icon_path

        shortcut.save()
        print(f"[+] Raccourci créé : {shortcut_path}")

    except ImportError:
        print("[!] Le module 'pywin32' n'est pas installé sur le Python système, "
              "impossible de créer un vrai raccourci .lnk (pip install pywin32).")
        print("[*] Création d'un lanceur .bat à la place...")

        bat_path = os.path.join(desktop_dir, f"{APP_NAME}.bat")
        content = (
            "@echo off\n"
            f'cd /d "{PROJECT_DIR}"\n'
            f'"{venv_exec}" "{MAIN_SCRIPT}"\n'
        )
        with open(bat_path, "w") as f:
            f.write(content)
        print(f"[+] Lanceur créé : {bat_path}")


def create_shortcut_macos():
    desktop_dir = os.path.join(os.path.expanduser("~"), "Desktop")
    command_path = os.path.join(desktop_dir, f"{APP_NAME}.command")
    venv_python = get_venv_python()

    content = (
        "#!/bin/bash\n"
        f'cd "{PROJECT_DIR}"\n'
        f'"{venv_python}" "{MAIN_SCRIPT}"\n'
    )
    with open(command_path, "w") as f:
        f.write(content)
    os.chmod(command_path, 0o755)

    print(f"[+] Lanceur créé : {command_path}")
    print("[i] Au premier lancement, macOS (Gatekeeper) peut demander un clic "
          "droit → Ouvrir plutôt qu'un simple double-clic.")


def create_shortcut():
    system = platform.system()
    print(f"[*] Système détecté : {system}")

    if system == "Linux":
        create_shortcut_linux()
    elif system == "Windows":
        create_shortcut_windows()
    elif system == "Darwin":
        create_shortcut_macos()
    else:
        print(f"[!] Système non reconnu ({system}), raccourci non créé.")


def main():
    print("=" * 50)
    print(f"  Installation de {APP_NAME} (environnement virtuel dédié)")
    print("=" * 50)
    create_venv()
    install_dependencies()
    create_shortcut()
    print("-" * 50)
    print(f"[OK] Installation terminée.")
    print(f"[i] Environnement virtuel : {VENV_DIR}")
    print("[i] Tu peux lancer l'application depuis le raccourci créé sur ton bureau.")


if __name__ == "__main__":
    main()