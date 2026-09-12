import sys
import threading
from tkinter import Tk
from utile.display import WatchFoxGUI
from module.phone import PhonyNode
from module.web import WebScanner
from module.mail import EmailOSINT
from module.pseudo import UsernameOSINT
from module.danger import URLAnalyzer
from module.dehash import HashCracker
from module.ia import IADetector
from module.info import SystemDevis
from module.meta import MetadataExtractor
from module.password import PasswordAnalyzer
from module.profileur import Profileur

def run_module(gui, mode):
    """Récupère la cible et lance le module dans un thread séparé."""
    target = gui.target_entry.get().strip()

    # Modules qui ne nécessitent pas de cible saisie
    NO_TARGET_MODES = {"sysinfo"}

    if not target and mode not in NO_TARGET_MODES:
        print("[!] Cible manquante dans le champ de saisie.")
        return

    # Lancement dans un thread pour ne pas freezer l'interface graphique
    scan_thread = threading.Thread(target=execute_scan, args=(target, mode))
    scan_thread.daemon = True
    scan_thread.start()


def execute_scan(target, mode):
    """Exécute la logique métier du module sélectionné."""
    label = target if target else "Machine Locale"
    print(f"[>] RECHERCHE {mode.upper()} : {label}")
    print("-" * 40)

    try:
        # ── OSINT ──────────────────────────────────────────────
        if mode == "phone":
            PhonyNode(target).run_scan()
        elif mode == "web":
            WebScanner(target).scan_infra()
        elif mode == "mail":
            EmailOSINT(target).run_scan()
        elif mode == "pseudo":
            UsernameOSINT(target).run_scan()
        elif mode == "profileur":
            Profileur(target).run_scan()

        # ── ANALYSE ────────────────────────────────────────────
        elif mode == "url":
            URLAnalyzer(target).run_scan()
        elif mode == "hash":
            HashCracker(target).run_scan()
        elif mode == "ia":
            IADetector(target).run_scan()
        elif mode == "metadata":
            MetadataExtractor(target).run_scan()
        elif mode == "password":
            PasswordAnalyzer(target).run_scan()

        # ── SYSTÈME ────────────────────────────────────────────
        elif mode == "sysinfo":
            SystemDevis().run_scan()

        else:
            print(f"[!] Mode inconnu : {mode}")

    except Exception as e:
        print(f"[!] Erreur de module ({mode}) : {e}")

    print(f"[OK] Scan {mode} terminé.")
    print("-" * 40)


def main():
    root = Tk()
    # L'initialisation de WatchFoxGUI gère déjà la redirection de sys.stdout
    app = WatchFoxGUI(root)

    # Dictionnaire de correspondance entre l'attribut dans app et le mode
    button_mapping = {
        'btn_phone': 'phone',
        'btn_web': 'web',
        'btn_mail': 'mail',
        'btn_pseudo': 'pseudo',
        'btn_profileur': 'profileur',
        'btn_url': 'url',
        'btn_hash': 'hash',
        'btn_ia': 'ia',
        'btn_meta': 'metadata',
        'btn_pass': 'password',
        'btn_sysinfo': 'sysinfo'
    }

    # Configuration dynamique des commandes
    for attr, mode in button_mapping.items():
        if hasattr(app, attr):
            btn = getattr(app, attr)
            # Utilisation de default value dans lambda pour éviter les problèmes de scope
            btn.config(command=lambda m=mode: run_module(app, m))

    root.mainloop()

if __name__ == "__main__":
    main()