#!/usr/bin/env python3
import customtkinter as ctk
import pyperclip
from crypto_utils import load_vault, save_vault

# ─── Theme ───────────────────────────────────────────────────────────────────
ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("dark-blue")

BG_DARK = "#1a1a2e"
BG_SIDEBAR = "#16213e"
BG_CARD = "#1e2a4a"
BG_INPUT = "#0f1729"
ACCENT = "#c850c0"
ACCENT_HOVER = "#e040b0"
TEXT_PRIMARY = "#e0e0e0"
TEXT_SECONDARY = "#8892a8"
TEXT_DIM = "#5a6478"
COPY_GREEN = "#4ade80"
BG_FOLDER = "#121a35"


class VaultApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("Vault")
        self.geometry("850x540")
        self.minsize(750, 420)
        self.configure(fg_color=BG_DARK)

        self.vault_data = load_vault()
        # Ensure folders structure exists
        if "folders" not in self.vault_data:
            # Migrate: put existing entries into "Generale"
            old_entries = self.vault_data.get("entries", [])
            self.vault_data = {
                "folders": [
                    {"name": "Generale", "entries": old_entries}
                ]
            }
            save_vault(self.vault_data)

        self.selected_folder = 0
        self.selected_entry = None

        self._build_ui()
        self._refresh_folders()
        self._refresh_entries()

        # Chiudere = nascondere
        self.protocol("WM_DELETE_WINDOW", self._hide_window)

        # Hotkey globale
        start_hotkey_listener(self)

        # Dock click riapre la finestra
        self._setup_dock_reopen()

        # Forza in primo piano
        self.lift()
        self.attributes("-topmost", True)
        self.after(500, lambda: self.attributes("-topmost", False))
        self.focus_force()

    def _hide_window(self):
        self.withdraw()

    def _setup_dock_reopen(self):
        """Usa il delegate nativo macOS per riaprire al click sul Dock."""
        try:
            import objc
            from AppKit import NSApplication, NSObject

            app_ref = self

            class AppDelegate(NSObject):
                def applicationShouldHandleReopen_hasVisibleWindows_(self, app, flag):
                    app_ref.after(0, app_ref.toggle_visibility)
                    return False

            ns_app = NSApplication.sharedApplication()
            self._delegate = AppDelegate.alloc().init()
            ns_app.setDelegate_(self._delegate)
        except ImportError:
            pass

    def _build_ui(self):
        main = ctk.CTkFrame(self, fg_color=BG_DARK)
        main.pack(expand=True, fill="both")
        main.columnconfigure(0, weight=0, minsize=180)
        main.columnconfigure(1, weight=1, minsize=200)
        main.columnconfigure(2, weight=2)
        main.rowconfigure(0, weight=1)

        # ── Folder panel (colonna sinistra) ──
        folder_panel = ctk.CTkFrame(main, fg_color=BG_DARK, corner_radius=0, width=180)
        folder_panel.grid(row=0, column=0, sticky="nsew")
        folder_panel.grid_propagate(False)

        ctk.CTkLabel(
            folder_panel, text="CARTELLE",
            font=("SF Pro Display", 11, "bold"), text_color=TEXT_DIM,
            anchor="w"
        ).pack(fill="x", padx=14, pady=(14, 6))

        self.folder_list = ctk.CTkScrollableFrame(
            folder_panel, fg_color="transparent",
            scrollbar_button_color=BG_CARD
        )
        self.folder_list.pack(expand=True, fill="both", padx=6, pady=0)

        folder_btn_frame = ctk.CTkFrame(folder_panel, fg_color="transparent")
        folder_btn_frame.pack(fill="x", padx=8, pady=8)

        ctk.CTkButton(
            folder_btn_frame, text="+", width=36, height=30,
            fg_color=BG_CARD, hover_color=BG_SIDEBAR,
            text_color=TEXT_SECONDARY, font=("SF Pro Display", 14),
            command=self._add_folder
        ).pack(side="left", padx=(0, 4))

        ctk.CTkButton(
            folder_btn_frame, text="Rinomina", width=70, height=30,
            fg_color=BG_CARD, hover_color=BG_SIDEBAR,
            text_color=TEXT_SECONDARY, font=("SF Pro Display", 11),
            command=self._rename_folder
        ).pack(side="left", padx=(0, 4))

        ctk.CTkButton(
            folder_btn_frame, text="x", width=30, height=30,
            fg_color=BG_CARD, hover_color="#ff4444",
            text_color="#ff6b6b", font=("SF Pro Display", 12),
            command=self._delete_folder
        ).pack(side="right")

        # ── Entries sidebar ──
        sidebar = ctk.CTkFrame(main, fg_color=BG_SIDEBAR, corner_radius=0)
        sidebar.grid(row=0, column=1, sticky="nsew")

        search_frame = ctk.CTkFrame(sidebar, fg_color="transparent")
        search_frame.pack(fill="x", padx=12, pady=(12, 6))

        self.search_var = ctk.StringVar()
        self.search_var.trace_add("write", lambda *_: self._refresh_entries())
        self.search_entry = ctk.CTkEntry(
            search_frame, placeholder_text="Cerca...",
            textvariable=self.search_var, height=36,
            fg_color=BG_INPUT, border_color=BG_INPUT,
            text_color=TEXT_PRIMARY, font=("SF Pro Display", 13)
        )
        self.search_entry.pack(fill="x")

        self.list_frame = ctk.CTkScrollableFrame(
            sidebar, fg_color="transparent",
            scrollbar_button_color=BG_CARD
        )
        self.list_frame.pack(expand=True, fill="both", padx=8, pady=4)

        add_btn = ctk.CTkButton(
            sidebar, text="+ Nuovo", height=36,
            fg_color=ACCENT, hover_color=ACCENT_HOVER,
            font=("SF Pro Display", 13, "bold"),
            command=self._add_new
        )
        add_btn.pack(fill="x", padx=12, pady=12)

        # ── Detail panel ──
        self.detail_panel = ctk.CTkFrame(main, fg_color=BG_DARK, corner_radius=0)
        self.detail_panel.grid(row=0, column=2, sticky="nsew")

        self.detail_content = ctk.CTkScrollableFrame(
            self.detail_panel, fg_color="transparent"
        )
        self.detail_content.pack(expand=True, fill="both", padx=20, pady=20)

        self._show_empty_detail()

    # ── Folders ──────────────────────────────────────────────────────────

    def _refresh_folders(self):
        for w in self.folder_list.winfo_children():
            w.destroy()

        for i, folder in enumerate(self.vault_data["folders"]):
            is_sel = (i == self.selected_folder)
            count = len(folder.get("entries", []))
            btn = ctk.CTkButton(
                self.folder_list,
                text=f"  {folder['name']}  ({count})",
                anchor="w",
                height=34,
                fg_color=BG_CARD if is_sel else "transparent",
                hover_color=BG_CARD,
                text_color=TEXT_PRIMARY if is_sel else TEXT_SECONDARY,
                font=("SF Pro Display", 12, "bold" if is_sel else "normal"),
                command=lambda idx=i: self._select_folder(idx)
            )
            btn.pack(fill="x", pady=1)

    def _select_folder(self, index):
        self.selected_folder = index
        self.selected_entry = None
        self._refresh_folders()
        self._refresh_entries()
        self._show_empty_detail()

    def _add_folder(self):
        dialog = ctk.CTkInputDialog(
            text="Nome della cartella:", title="Nuova cartella"
        )
        name = dialog.get_input()
        if name and name.strip():
            self.vault_data["folders"].append({"name": name.strip(), "entries": []})
            save_vault(self.vault_data)
            self.selected_folder = len(self.vault_data["folders"]) - 1
            self._refresh_folders()
            self._refresh_entries()

    def _rename_folder(self):
        if self.selected_folder is None:
            return
        folder = self.vault_data["folders"][self.selected_folder]
        dialog = ctk.CTkInputDialog(
            text="Nuovo nome:", title="Rinomina cartella"
        )
        name = dialog.get_input()
        if name and name.strip():
            folder["name"] = name.strip()
            save_vault(self.vault_data)
            self._refresh_folders()

    def _delete_folder(self):
        if self.selected_folder is None or len(self.vault_data["folders"]) <= 1:
            return
        self.vault_data["folders"].pop(self.selected_folder)
        save_vault(self.vault_data)
        self.selected_folder = 0
        self.selected_entry = None
        self._refresh_folders()
        self._refresh_entries()
        self._show_empty_detail()

    # ── Entries ──────────────────────────────────────────────────────────

    def _current_entries(self):
        if self.selected_folder is not None and self.selected_folder < len(self.vault_data["folders"]):
            return self.vault_data["folders"][self.selected_folder].get("entries", [])
        return []

    def _show_empty_detail(self):
        for w in self.detail_content.winfo_children():
            w.destroy()
        ctk.CTkLabel(
            self.detail_content, text="Seleziona un tool",
            font=("SF Pro Display", 16), text_color=TEXT_DIM
        ).pack(expand=True)

    def _refresh_entries(self):
        for w in self.list_frame.winfo_children():
            w.destroy()

        query = self.search_var.get().lower().strip()
        entries = self._current_entries()

        for i, entry in enumerate(entries):
            if query and query not in entry["name"].lower():
                continue
            is_selected = (i == self.selected_entry)
            btn = ctk.CTkButton(
                self.list_frame,
                text=entry["name"],
                anchor="w",
                height=40,
                fg_color=BG_CARD if is_selected else "transparent",
                hover_color=BG_CARD,
                text_color=TEXT_PRIMARY if is_selected else TEXT_SECONDARY,
                font=("SF Pro Display", 13, "bold" if is_selected else "normal"),
                command=lambda idx=i: self._select_entry(idx)
            )
            btn.pack(fill="x", pady=1)

    def _select_entry(self, index):
        self.selected_entry = index
        self._refresh_entries()
        self._show_detail(self._current_entries()[index])

    def _show_detail(self, entry):
        for w in self.detail_content.winfo_children():
            w.destroy()

        header = ctk.CTkFrame(self.detail_content, fg_color="transparent")
        header.pack(fill="x", pady=(0, 20))

        ctk.CTkLabel(
            header, text=entry["name"],
            font=("SF Pro Display", 22, "bold"), text_color=TEXT_PRIMARY,
            anchor="w"
        ).pack(side="left")

        btn_frame = ctk.CTkFrame(header, fg_color="transparent")
        btn_frame.pack(side="right")

        ctk.CTkButton(
            btn_frame, text="Modifica", width=80, height=32,
            fg_color=BG_CARD, hover_color=BG_SIDEBAR,
            text_color=TEXT_SECONDARY, font=("SF Pro Display", 12),
            command=lambda: self._edit_entry(entry)
        ).pack(side="left", padx=(0, 6))

        ctk.CTkButton(
            btn_frame, text="Elimina", width=70, height=32,
            fg_color=BG_CARD, hover_color="#ff4444",
            text_color="#ff6b6b", font=("SF Pro Display", 12),
            command=lambda: self._delete_entry(entry)
        ).pack(side="left")

        # Copy all
        ctk.CTkButton(
            self.detail_content, text="Copia tutto", height=36,
            fg_color=BG_CARD, hover_color=BG_SIDEBAR,
            text_color=COPY_GREEN, font=("SF Pro Display", 13, "bold"),
            anchor="w",
            command=lambda: self._copy_all(entry)
        ).pack(fill="x", pady=(0, 16))

        for field in entry.get("fields", []):
            self._render_field(field)

    def _render_field(self, field):
        card = ctk.CTkFrame(self.detail_content, fg_color=BG_CARD, corner_radius=10)
        card.pack(fill="x", pady=(0, 8))

        top = ctk.CTkFrame(card, fg_color="transparent")
        top.pack(fill="x", padx=14, pady=(10, 4))

        ctk.CTkLabel(
            top, text=field["label"].upper(),
            font=("SF Pro Display", 11, "bold"), text_color=TEXT_DIM,
            anchor="w"
        ).pack(side="left")

        copy_btn = ctk.CTkButton(
            top, text="Copia", width=60, height=26,
            fg_color="transparent", hover_color=BG_SIDEBAR,
            text_color=ACCENT, font=("SF Pro Display", 11),
            command=lambda v=field["value"]: self._copy_single(v, copy_btn)
        )
        copy_btn.pack(side="right")

        display_value = "●" * min(len(field["value"]), 20) if field.get("secret") else field["value"]
        value_label = ctk.CTkLabel(
            card, text=display_value or "—",
            font=("SF Mono", 13), text_color=TEXT_PRIMARY,
            anchor="w"
        )
        value_label.pack(fill="x", padx=14, pady=(0, 10))

        if field.get("secret") and field["value"]:
            shown = [False]

            def toggle(lbl=value_label, f=field):
                if shown[0]:
                    lbl.configure(text="●" * min(len(f["value"]), 20))
                else:
                    lbl.configure(text=f["value"])
                shown[0] = not shown[0]

            value_label.bind("<Button-1>", lambda e: toggle())
            value_label.configure(cursor="hand2")

    def _copy_single(self, value, btn):
        pyperclip.copy(value)
        original = btn.cget("text")
        btn.configure(text="Copiato!", text_color=COPY_GREEN)
        self.after(1000, lambda: btn.configure(text=original, text_color=ACCENT))

    def _copy_all(self, entry):
        lines = []
        for f in entry.get("fields", []):
            lines.append(f"{f['label']}: {f['value']}")
        pyperclip.copy("\n".join(lines))

    def _add_new(self):
        AddEditDialog(self, self._on_save_entry)

    def _edit_entry(self, entry):
        AddEditDialog(self, self._on_save_entry, entry=entry)

    def _on_save_entry(self, new_data, old_entry=None):
        entries = self._current_entries()
        if old_entry:
            idx = next((i for i, e in enumerate(entries) if e is old_entry), None)
            if idx is not None:
                entries[idx] = new_data
        else:
            entries.append(new_data)
        save_vault(self.vault_data)
        self._refresh_entries()
        self._refresh_folders()
        idx = next((i for i, e in enumerate(entries) if e["name"] == new_data["name"]), 0)
        self._select_entry(idx)

    def _delete_entry(self, entry):
        self._current_entries().remove(entry)
        save_vault(self.vault_data)
        self.selected_entry = None
        self._refresh_entries()
        self._refresh_folders()
        self._show_empty_detail()

    def toggle_visibility(self):
        if self.state() == "withdrawn" or not self.winfo_viewable():
            self.deiconify()
            self.lift()
            self.attributes("-topmost", True)
            self.after(300, lambda: self.attributes("-topmost", False))
            self.focus_force()
            self.search_entry.focus()
        else:
            self.withdraw()


class AddEditDialog(ctk.CTkToplevel):
    def __init__(self, master, on_save, entry=None):
        super().__init__(master)
        self.on_save = on_save
        self.entry = entry
        self.title("Modifica" if entry else "Nuovo")
        self.geometry("500x550")
        self.resizable(False, True)
        self.configure(fg_color=BG_DARK)
        self.transient(master)
        self.grab_set()

        container = ctk.CTkScrollableFrame(self, fg_color=BG_DARK)
        container.pack(expand=True, fill="both", padx=20, pady=20)

        ctk.CTkLabel(
            container, text="Nome del tool", font=("SF Pro Display", 13, "bold"),
            text_color=TEXT_SECONDARY, anchor="w"
        ).pack(fill="x", pady=(0, 5))
        self.name_entry = ctk.CTkEntry(
            container, placeholder_text="es. Supabase Personale",
            height=38, fg_color=BG_INPUT, border_color=BG_CARD,
            text_color=TEXT_PRIMARY, font=("SF Pro Display", 14)
        )
        self.name_entry.pack(fill="x", pady=(0, 15))

        ctk.CTkLabel(
            container, text="Campi", font=("SF Pro Display", 13, "bold"),
            text_color=TEXT_SECONDARY, anchor="w"
        ).pack(fill="x", pady=(0, 5))

        self.fields_frame = ctk.CTkFrame(container, fg_color="transparent")
        self.fields_frame.pack(fill="x", pady=(0, 10))

        self.field_rows = []

        if entry:
            self.name_entry.insert(0, entry["name"])
            for field in entry.get("fields", []):
                self._add_field_row(field["label"], field["value"], field.get("secret", False))
        else:
            self._add_field_row("Email", "", False)
            self._add_field_row("Password", "", True)

        ctk.CTkButton(
            container, text="+ Aggiungi campo", width=150, height=32,
            fg_color=BG_CARD, hover_color=BG_SIDEBAR,
            text_color=TEXT_SECONDARY, font=("SF Pro Display", 12),
            command=lambda: self._add_field_row("", "", False)
        ).pack(anchor="w", pady=(0, 20))

        btn_frame = ctk.CTkFrame(container, fg_color="transparent")
        btn_frame.pack(fill="x")

        ctk.CTkButton(
            btn_frame, text="Annulla", width=100, height=36,
            fg_color=BG_CARD, hover_color=BG_SIDEBAR,
            text_color=TEXT_SECONDARY, font=("SF Pro Display", 13),
            command=self.destroy
        ).pack(side="left")

        ctk.CTkButton(
            btn_frame, text="Salva", width=100, height=36,
            fg_color=ACCENT, hover_color=ACCENT_HOVER,
            font=("SF Pro Display", 13, "bold"),
            command=self._save
        ).pack(side="right")

    def _add_field_row(self, label="", value="", secret=False):
        row = ctk.CTkFrame(self.fields_frame, fg_color=BG_CARD, corner_radius=8)
        row.pack(fill="x", pady=(0, 8))

        top = ctk.CTkFrame(row, fg_color="transparent")
        top.pack(fill="x", padx=10, pady=(8, 4))

        label_entry = ctk.CTkEntry(
            top, placeholder_text="Nome campo",
            width=160, height=30, fg_color=BG_INPUT, border_color=BG_INPUT,
            text_color=TEXT_PRIMARY, font=("SF Pro Display", 12)
        )
        label_entry.pack(side="left")
        if label:
            label_entry.insert(0, label)

        secret_var = ctk.BooleanVar(value=secret)
        ctk.CTkCheckBox(
            top, text="Segreto", variable=secret_var,
            font=("SF Pro Display", 11), text_color=TEXT_DIM,
            fg_color=ACCENT, hover_color=ACCENT_HOVER,
            width=20, height=20
        ).pack(side="left", padx=(10, 0))

        del_btn = ctk.CTkButton(
            top, text="x", width=28, height=28,
            fg_color="transparent", hover_color="#ff4444",
            text_color=TEXT_DIM, font=("SF Pro Display", 12),
            command=lambda: self._remove_field(row, row_data)
        )
        del_btn.pack(side="right")

        value_entry = ctk.CTkEntry(
            row, placeholder_text="Valore",
            height=32, fg_color=BG_INPUT, border_color=BG_INPUT,
            text_color=TEXT_PRIMARY, font=("SF Pro Display", 13),
            show="*" if secret else ""
        )
        value_entry.pack(fill="x", padx=10, pady=(0, 8))
        if value:
            value_entry.insert(0, value)

        row_data = {
            "frame": row,
            "label": label_entry,
            "value": value_entry,
            "secret": secret_var
        }
        self.field_rows.append(row_data)

    def _remove_field(self, frame, row_data):
        frame.destroy()
        if row_data in self.field_rows:
            self.field_rows.remove(row_data)

    def _save(self):
        name = self.name_entry.get().strip()
        if not name:
            return
        fields = []
        for row in self.field_rows:
            label = row["label"].get().strip()
            value = row["value"].get().strip()
            if label:
                fields.append({
                    "label": label,
                    "value": value,
                    "secret": row["secret"].get()
                })
        entry_data = {"name": name, "fields": fields}
        self.on_save(entry_data, self.entry)
        self.destroy()


def start_hotkey_listener(app):
    """Use Quartz CGEvent tap for global hotkey (Cmd+Shift+P). Works even when app is hidden."""
    import Quartz
    import threading

    P_KEYCODE = 35
    CMD_SHIFT = Quartz.kCGEventFlagMaskCommand | Quartz.kCGEventFlagMaskShift

    def callback(proxy, event_type, event, refcon):
        if event_type == Quartz.kCGEventKeyDown:
            keycode = Quartz.CGEventGetIntegerValueField(event, Quartz.kCGKeyboardEventKeycode)
            flags = Quartz.CGEventGetFlags(event)
            if keycode == P_KEYCODE and (flags & CMD_SHIFT) == CMD_SHIFT:
                app.after(0, app.toggle_visibility)
        return event

    def run_tap():
        tap = Quartz.CGEventTapCreate(
            Quartz.kCGSessionEventTap,
            Quartz.kCGHeadInsertEventTap,
            Quartz.kCGEventTapOptionListenOnly,
            Quartz.CGEventMaskBit(Quartz.kCGEventKeyDown),
            callback,
            None
        )
        if tap is None:
            print("Impossibile creare event tap. Aggiungi l'app ai permessi di Accessibilita'.", flush=True)
            return

        source = Quartz.CFMachPortCreateRunLoopSource(None, tap, 0)
        loop = Quartz.CFRunLoopGetCurrent()
        Quartz.CFRunLoopAddSource(loop, source, Quartz.kCFRunLoopDefaultMode)
        Quartz.CGEventTapEnable(tap, True)
        Quartz.CFRunLoopRun()

    t = threading.Thread(target=run_tap, daemon=True)
    t.start()


def main():
    app = VaultApp()
    app.mainloop()


if __name__ == "__main__":
    main()
