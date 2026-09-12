import platform
import psutil
import subprocess
import os
from datetime import datetime

class SystemDevis:
    def __init__(self, target=None):
        # target est ignoré ici car on scanne la machine locale
        self.os_type = platform.system().lower()
        self.is_android = 'ANDROID_STORAGE' in os.environ

    def get_info(self, cmd):
        try:
            return subprocess.check_output(cmd, shell=True, stderr=subprocess.DEVNULL).decode().strip()
        except:
            return "N/A"

    def run_scan(self):
        """Génère le rapport système et l'affiche dans la console GUI"""
        print("\n[#] GÉNÉRATION DU RAPPORT SYSTÈME")
        print("-" * 40)
        
        # --- Système d'exploitation ---
        os_name = "Android" if self.is_android else platform.system()
        print(f"[>] OS : {os_name} {platform.release()}")
        print(f"[>] Architecture : {platform.machine()}")

        # --- CPU ---
        cpu_model = "Inconnu"
        if self.os_type == "windows":
            cpu_model = self.get_info("wmic cpu get name").split('\n')[-1]
        elif self.os_type == "linux" or self.is_android:
            cpu_model = self.get_info("grep -m 1 'model name' /proc/cpuinfo | cut -d: -f2")
        elif self.os_type == "darwin":
            cpu_model = self.get_info("sysctl -n machdep.cpu.brand_string")
        
        print(f"[>] CPU : {cpu_model.strip()}")
        print(f"[>] Cœurs : {psutil.cpu_count(logical=False)} Physiques / {psutil.cpu_count()} Logiques")

        # --- Mémoire ---
        mem = psutil.virtual_memory()
        print(f"[>] RAM Total : {round(mem.total / (1024**3), 2)} Go")
        print(f"[>] RAM Utilisée : {mem.percent}%")

        # --- GPU ---
        if self.os_type == "windows":
            gpu = self.get_info("wmic path win32_VideoController get name").split('\n')[-1]
            print(f"[>] GPU : {gpu.strip()}")
        elif self.os_type == "linux":
            gpu = self.get_info("lspci | grep VGA | cut -d ':' -f3")
            print(f"[>] GPU : {gpu.strip()}")

        # --- Batterie ---
        batt = psutil.sensors_battery()
        if batt:
            status = 'Secteur' if batt.power_plugged else 'Batterie'
            print(f"[>] Énergie : {batt.percent}% ({status})")

        print("-" * 40)
        print("[OK] Rapport terminé.")