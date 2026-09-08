#!/usr/bin/env bash
# ====================================================
# TraeWork Auto Check-in - Autostart Manager (macOS / Linux)
# ====================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$SCRIPT_DIR/run_checkin.sh"

install_macos() {
  echo "[*] Configuring macOS LaunchAgent..."
  PLIST_DIR="$HOME/Library/LaunchAgents"
  PLIST_FILE="$PLIST_DIR/com.traework.autocheckin.plist"
  mkdir -p "$PLIST_DIR"

  cat <<EOF > "$PLIST_FILE"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.traework.autocheckin</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$RUNNER</string>
        <string>--silent</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$SCRIPT_DIR/checkin.log</string>
    <key>StandardErrorPath</key>
    <string>$SCRIPT_DIR/checkin.log</string>
</dict>
</plist>
EOF

  launchctl unload "$PLIST_FILE" 2>/dev/null || true
  launchctl load "$PLIST_FILE"
  echo "[OK] macOS autostart task installed successfully!"
  echo "TraeWork check-in will run automatically on user login."
}

uninstall_macos() {
  echo "[*] Removing macOS LaunchAgent..."
  PLIST_FILE="$HOME/Library/LaunchAgents/com.traework.autocheckin.plist"
  if [ -f "$PLIST_FILE" ]; then
    launchctl unload "$PLIST_FILE" 2>/dev/null || true
    rm -f "$PLIST_FILE"
    echo "[OK] LaunchAgent removed successfully."
  else
    echo "[INFO] No LaunchAgent found."
  fi
}

install_linux() {
  echo "[*] Configuring Linux XDG autostart entry..."
  AUTOSTART_DIR="$HOME/.config/autostart"
  DESKTOP_FILE="$AUTOSTART_DIR/traework_autocheckin.desktop"
  mkdir -p "$AUTOSTART_DIR"

  cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Type=Application
Version=1.0
Name=TraeWork Auto Check-in
Comment=TraeWork Daily Auto Check-in
Exec=/bin/bash "$RUNNER" --silent
Terminal=false
Hidden=false
X-GNOME-Autostart-enabled=true
EOF

  chmod +x "$DESKTOP_FILE"
  echo "[OK] Linux desktop autostart entry installed successfully!"
}

uninstall_linux() {
  echo "[*] Removing Linux autostart entry..."
  DESKTOP_FILE="$HOME/.config/autostart/traework_autocheckin.desktop"
  if [ -f "$DESKTOP_FILE" ]; then
    rm -f "$DESKTOP_FILE"
    echo "[OK] Autostart desktop entry removed."
  else
    echo "[INFO] No autostart desktop entry found."
  fi
}

do_install() {
  case "$(uname -s)" in
    Darwin*) install_macos ;;
    Linux*)  install_linux ;;
    *)       echo "[ERROR] Unsupported operating system: $(uname -s)" ;;
  esac
}

do_uninstall() {
  case "$(uname -s)" in
    Darwin*) uninstall_macos ;;
    Linux*)  uninstall_linux ;;
    *)       echo "[ERROR] Unsupported operating system: $(uname -s)" ;;
  esac
}

# Handle command line arguments
if [ "$1" = "--install" ] || [ "$1" = "-i" ]; then
  do_install
  exit 0
elif [ "$1" = "--uninstall" ] || [ "$1" = "-u" ]; then
  do_uninstall
  exit 0
fi

# Interactive menu
while true; do
  echo "===================================================="
  echo "   TraeWork Auto Check-in - Autostart Manager"
  echo "   OS: $(uname -s)"
  echo "===================================================="
  echo "  [1] Install autostart task (Run on user login)"
  echo "  [2] Uninstall autostart task (Remove completely)"
  echo "  [3] Run check-in now (Test execution)"
  echo "  [0] Exit"
  echo "===================================================="
  read -p "Enter choice [1/2/3/0]: " choice
  case "$choice" in
    1)
      do_install
      read -p "Press Enter to return to menu..." _
      ;;
    2)
      do_uninstall
      read -p "Press Enter to return to menu..." _
      ;;
    3)
      /bin/bash "$RUNNER"
      read -p "Press Enter to return to menu..." _
      ;;
    0|[qQ])
      echo "Exiting..."
      exit 0
      ;;
    *)
      echo "[ERROR] Invalid choice: $choice"
      sleep 1
      ;;
  esac
done