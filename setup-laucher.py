import os
import sys
import subprocess
import platform

def setup():
    # 1. Installer les dépendances
    libs = ["requests", "pillow", "rich", "phonenumbers"]
    if platform.system() == "Windows": libs.append("pywin32")
    
    print("[*] Installation des dépendances...")
    for lib in libs:
        subprocess.check_call([sys.executable, "-m", "pip", "install", lib])

    # 2. Créer le raccourci sur le Bureau
    current_dir = os.path.dirname(os.path.abspath(__file__))
    main_script = os.path.join(current_dir, "main.py")
    system = platform.system()

    if system == "Windows":
        from win32com.client import Dispatch
        desktop = os.path.join(os.environ['USERPROFILE'], 'Desktop')
        path = os.path.join(desktop, "WatchFox.lnk")
        shell = Dispatch('WScript.Shell')
        shortcut = shell.CreateShortCut(path)
        shortcut.Targetpath = sys.executable
        shortcut.Arguments = f'"{main_script}"'
        shortcut.WorkingDirectory = current_dir
        shortcut.save()
        print("[OK] Raccourci Windows créé.")

    elif system == "Linux":
        desktop_path = os.path.expanduser("~/Desktop")
        if not os.path.exists(desktop_path): desktop_path = os.path.expanduser("~/Bureau")
        
        launch_file = os.path.join(desktop_path, "watchfox.desktop")
        content = f"[Desktop Entry]\nType=Application\nName=WatchFox\nExec={sys.executable} {main_script}\nPath={current_dir}\nTerminal=false\n"
        
        with open(launch_file, "w") as f: f.write(content)
        os.chmod(launch_file, 0o755)
        print("[OK] Raccourci Linux créé (pensez à faire clic-droit > Autoriser le lancement).")

if __name__ == "__main__":
    setup()