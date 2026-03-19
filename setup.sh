#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$PROJECT_DIR/.venv"
PLIST_NAME="com.raffaele.vault"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"

echo "🔒 Vault - Setup"
echo "================="

# 1. Crea virtual environment
echo "→ Creazione virtual environment..."
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

# 2. Installa dipendenze
echo "→ Installazione dipendenze..."
pip install -r "$PROJECT_DIR/requirements.txt" --quiet

# 3. Crea LaunchAgent per avvio al login
echo "→ Configurazione avvio al login..."
cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>$VENV_DIR/bin/python</string>
        <string>$PROJECT_DIR/main.py</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardErrorPath</key>
    <string>/tmp/vault-error.log</string>
    <key>StandardOutPath</key>
    <string>/tmp/vault-out.log</string>
</dict>
</plist>
EOF

# 4. Carica il LaunchAgent
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo ""
echo "✅ Setup completato!"
echo ""
echo "• L'app si avvierà automaticamente al prossimo login"
echo "• Shortcut globale: Cmd+Shift+P per aprire/nascondere"
echo "• Per avviarla ora: $VENV_DIR/bin/python $PROJECT_DIR/main.py"
echo "• I dati criptati sono in: ~/.local_vault/"
