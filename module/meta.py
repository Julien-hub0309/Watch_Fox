import os
from PIL import Image
from PIL.ExifTags import TAGS
from hachoir.parser import createParser
from hachoir.metadata import extractMetadata

class MetadataExtractor:
    def __init__(self, path):
        # Nettoyage du chemin (cas des guillemets lors d'un drag & drop)
        self.path = path.replace('"', '').replace("'", "").strip()

    def run_scan(self):
        """Logique d'extraction exécutée dans le thread de main.py"""
        if not os.path.exists(self.path):
            print(f"[!] Fichier introuvable : {self.path}")
            return

        print(f"[*] ANALYSE DES MÉTADONNÉES : {os.path.basename(self.path)}")
        
        # --- Métadonnées Image (EXIF) ---
        if self.path.lower().endswith(('.jpg', '.jpeg', '.png', '.tiff')):
            try:
                with Image.open(self.path) as img:
                    info = img._getexif()
                    if info:
                        print("\n[>] DONNÉES EXIF (IMAGE) :")
                        for tag, value in info.items():
                            tag_name = TAGS.get(tag, tag)
                            print(f"  - {tag_name}: {value}")
            except Exception as e:
                print(f"[!] Erreur EXIF : {e}")

        # --- Métadonnées Générales (via Hachoir) ---
        try:
            parser = createParser(self.path)
            if parser:
                metadata = extractMetadata(parser)
                if metadata:
                    print("\n[>] INFORMATIONS GÉNÉRALES :")
                    for line in metadata.exportPlaintext():
                        print(f"  {line}")
                parser.stream._input.close()
        except Exception as e:
            print(f"[!] Erreur Hachoir : {e}")
            
        print("\n[OK] Analyse des métadonnées terminée.")