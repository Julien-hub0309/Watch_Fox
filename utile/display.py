import urllib.request
import socket
import sys
from tkinter import Tk, Label, Button, Entry, END, Canvas, NW, Frame, Text, Scrollbar
from PIL import Image, ImageTk

# ──────────────────────────────────────────────────────────────
#  PALETTE "WATCH_FOX" (identique à la direction artistique de main.dart)
# ──────────────────────────────────────────────────────────────
COLOR_BG_DEEP   = "#0A0A0A"   # kDeepBlack
COLOR_BG_PANEL  = "#101418"   # variante sombre pour les panneaux
COLOR_CYAN      = "#40B0FF"   # kCyanAccent
COLOR_BLUE_DARK = "#80B0FF"   # kBlueDark
COLOR_GREEN     = "#39FF6A"   # succès / tag LOCAL
COLOR_RED       = "#FF5C5C"   # erreurs
COLOR_WHITE_DIM = "#B0C4D4"   # texte par défaut de la console
COLOR_BORDER    = "#2A2F35"   # bordure neutre des boutons non actifs

# ──────────────────────────────────────────────────────────────
#  CONSOLE GLOBALE
# ──────────────────────────────────────────────────────────────

class FakeConsole:
    def __init__(self):
        self.text_widget = None

    def get_public_ip(self):
        try:
            return urllib.request.urlopen('https://api4.ipify.org', timeout=3).read().decode('utf8')
        except:
            return "Indisponible"

    def get_hostname(self):
        try:
            return socket.gethostname()
        except:
            return "Inconnu"

    def set_widget(self, widget):
        self.text_widget = widget
        # Tags de coloration façon "Watch_Fox" (même logique de mapping que main.dart)
        self.text_widget.tag_config("success", foreground=COLOR_GREEN)
        self.text_widget.tag_config("error", foreground=COLOR_RED)
        self.text_widget.tag_config("info", foreground=COLOR_CYAN)
        self.text_widget.tag_config("sep", foreground=COLOR_BLUE_DARK)
        self.text_widget.tag_config("default", foreground=COLOR_WHITE_DIM)

    def print(self, *args, **kwargs):
        if not self.text_widget:
            return
        raw_msg = " ".join(map(str, args))

        if "[+]" in raw_msg or "FOUND" in raw_msg.upper():
            formatted_msg, tag = f"  ✔ {raw_msg}\n", "success"
        elif "[!]" in raw_msg or "ERROR" in raw_msg.upper():
            formatted_msg, tag = f"  ✘ {raw_msg}\n", "error"
        elif "[>]" in raw_msg:
            formatted_msg, tag = f"\n┏━━━━ {raw_msg} ━━━━┓\n", "sep"
        elif "-" * 10 in raw_msg:
            formatted_msg, tag = "┗" + "━" * 40 + "┛\n", "sep"
        elif "[V]" in raw_msg or "[OK]" in raw_msg:
            formatted_msg, tag = f"  ✔ {raw_msg}\n", "success"
        elif "[X]" in raw_msg or "[!!!]" in raw_msg:
            formatted_msg, tag = f"  ✘ {raw_msg}\n", "error"
        elif "[*]" in raw_msg or "[~]" in raw_msg:
            formatted_msg, tag = f"  ⟳ {raw_msg}\n", "info"
        else:
            formatted_msg, tag = f"    • {raw_msg}\n", "default"

        self.text_widget.insert(END, formatted_msg, tag)
        self.text_widget.see(END)
        self.text_widget.update_idletasks()

console = FakeConsole()

# ──────────────────────────────────────────────────────────────
#  REDIRECTEUR stdout → FakeConsole
# ──────────────────────────────────────────────────────────────

class RedirectText:
    def __init__(self):
        self.buffer = ""

    def write(self, string):
        self.buffer += string
        while "\n" in self.buffer:
            line, self.buffer = self.buffer.split("\n", 1)
            if line.strip():
                console.print(line)

    def flush(self):
        if self.buffer.strip():
            console.print(self.buffer)
            self.buffer = ""

# ──────────────────────────────────────────────────────────────
#  GUI
# ──────────────────────────────────────────────────────────────

class WatchFoxGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("WATCH_FOX V2.0 — OSINT")
        self.root.geometry("900x950")
        self.root.configure(bg=COLOR_BG_DEEP)

        # ── Canvas fond ───────────────────────────────────────
        self.canvas = Canvas(self.root, highlightthickness=0, bg=COLOR_BG_DEEP)
        self.canvas.place(x=0, y=0, relwidth=1, relheight=1)

        try:
            self.original_image = Image.open("background.png")
            self.bg_photo = ImageTk.PhotoImage(self.original_image.resize((900, 950)))
            self.bg_canvas_id = self.canvas.create_image(0, 0, image=self.bg_photo, anchor=NW)
        except:
            self.original_image = None

        # ── Tableau d'infos (recoloré en cyan "Watch_Fox") ────
        info_text = (
            f"╭──────────────────────────────────────────╮\n"
            f"│ ⌁ WATCH_FOX V2.0                          │\n"
            f"│ Intelligence & Investigation Framework   │\n"
            f"│ ──────────────────────────────────────── │\n"
            f"│ Device : {console.get_hostname():<30}  │\n"
            f"│ IPv4   : {console.get_public_ip():<30}  │\n"
            f"╰──────────────────────────────────────────╯"
        )

        self.info_table_id = self.canvas.create_text(
            20, 20,
            text=info_text,
            fill=COLOR_CYAN,
            font=("Courier", 12, "bold"),
            anchor="nw",
            justify="left"
        )

        # ── Zone saisie + boutons ─────────────────────────────
        self.ui_container = Frame(self.root, bg="", bd=0)
        self.ui_window = self.canvas.create_window(450, 220, window=self.ui_container, width=860)

        self.target_entry = Entry(
            self.ui_container,
            bg=COLOR_BG_DEEP, fg=COLOR_CYAN, insertbackground=COLOR_CYAN,
            font=("Courier", 16), justify="center", bd=2, relief="flat",
            highlightbackground=COLOR_CYAN, highlightcolor=COLOR_CYAN, highlightthickness=1
        )
        self.target_entry.pack(fill="x", pady=(8, 4), ipady=12)

        # ── Palette de boutons (unifiée cyan / bleu "Watch_Fox") ──
        ROWS = [
            {
                "label":  "◈  OSINT",
                "fg":     COLOR_CYAN, "bg": COLOR_BG_PANEL, "hover": COLOR_CYAN, "border": COLOR_CYAN,
                "buttons": [("btn_phone", "[ PHONE ]"), ("btn_web", "[ WEB/IP ]"), ("btn_mail", "[ EMAIL ]"), ("btn_pseudo", "[ PSEUDO ]")]
            },
            {
                "label":  "◈  ANALYSE",
                "fg":     COLOR_BLUE_DARK, "bg": COLOR_BG_PANEL, "hover": COLOR_BLUE_DARK, "border": COLOR_BLUE_DARK,
                "buttons": [("btn_url", "[ URL SCAN ]"), ("btn_hash", "[ DEHASH ]"), ("btn_pass", "[ PASSWORD ]"), ("btn_meta", "[ METADATA ]")]
            },
            {
                "label":  "◈  SYSTÈME",
                "fg":     COLOR_CYAN, "bg": COLOR_BG_PANEL, "hover": COLOR_GREEN, "border": COLOR_GREEN,
                "buttons": [("btn_ia", "[ IA DETECT ]"), ("btn_profileur", "[ PROFILEUR ]"), ("btn_sysinfo", "[ SYS INFO ]")]
            },
        ]

        for row_cfg in ROWS:
            fg, bg, hover, border = row_cfg["fg"], row_cfg["bg"], row_cfg["hover"], row_cfg["border"]
            section = Frame(self.ui_container, bg=border, pady=1)
            section.pack(fill="x", pady=(6, 0))
            inner = Frame(section, bg=bg)
            inner.pack(fill="x")

            Label(inner, text=row_cfg["label"], bg=bg, fg=fg, font=("Courier", 8, "bold"), anchor="w", padx=8).pack(fill="x")
            btn_row = Frame(inner, bg=bg)
            btn_row.pack(fill="x", padx=4, pady=(0, 4))

            for i, (attr, label) in enumerate(row_cfg["buttons"]):
                btn_row.columnconfigure(i, weight=1)
                btn = Button(btn_row, text=label, bg=bg, fg=fg, activebackground=hover, activeforeground=COLOR_BG_DEEP,
                             relief="flat", font=("Courier", 10, "bold"), height=2, bd=0, cursor="hand2",
                             highlightbackground=COLOR_BORDER, highlightthickness=1)
                btn.grid(row=0, column=i, padx=3, sticky="ew")
                btn.bind("<Enter>", lambda e, b=btn, h=hover: b.config(bg=h, fg=COLOR_BG_DEEP))
                btn.bind("<Leave>", lambda e, b=btn, c=bg, f=fg: b.config(bg=c, fg=f))
                setattr(self, attr, btn)

                # Petit badge "LOCAL" pour le module ne nécessitant pas de cible
                if attr == "btn_sysinfo":
                    Label(btn_row, text="⌁ LOCAL", bg=bg, fg=COLOR_GREEN,
                          font=("Courier", 7, "bold")).grid(row=1, column=i, sticky="ew")

        # ── Terminal ──────────────────────────────────────────
        self.term_frame = Frame(self.root, bg=COLOR_BG_DEEP, bd=1, relief="solid",
                                 highlightbackground=COLOR_CYAN, highlightthickness=1)
        self.term_frame.place(relx=0.5, rely=0.48, anchor="n", relwidth=0.96, relheight=0.49)

        self.terminal_text = Text(
            self.term_frame, bg="#050505", fg=COLOR_WHITE_DIM,
            font=("Courier New", 11), relief="flat",
            padx=15, pady=15, insertbackground=COLOR_CYAN
        )
        self.scrollbar = Scrollbar(self.term_frame, command=self.terminal_text.yview)
        self.terminal_text.config(yscrollcommand=self.scrollbar.set)
        self.terminal_text.pack(side="left", fill="both", expand=True)
        self.scrollbar.pack(side="right", fill="y")

        console.set_widget(self.terminal_text)
        sys.stdout = RedirectText()
        self.root.bind('<Configure>', self.on_resize)

        print("[>] WATCH FOX V2.0 - SYSTEM READY")
        print("[*] En attente d'une cible...")
        print("-" * 20)

    def on_resize(self, event):
        if event.widget != self.root or self.original_image is None:
            return
        try:
            new_w, new_h = event.width, event.height
            resized = self.original_image.resize((new_w, new_h), Image.LANCZOS)
            self.bg_photo = ImageTk.PhotoImage(resized)
            self.canvas.itemconfig(self.bg_canvas_id, image=self.bg_photo)
            cx = new_w // 2
            self.canvas.coords(self.info_table_id, 20, 20)
            self.canvas.coords(self.ui_window, cx, 220)  # Légèrement descendu pour éviter le chevauchement si redimensionné petit
        except:
            pass