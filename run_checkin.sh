#!/usr/bin/env bash
# ============================================
# TraeWork Daily Auto Check-in Runner (macOS / Linux)
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/checkin.js"

# 1. Check if Node.js is installed and meets modern requirements
if command -v node >/dev/null 2>&1; then
  if node -e "if(typeof fetch!=='function'||!require('crypto').subtle)process.exit(1)" >/dev/null 2>&1; then
    node "$SCRIPT_PATH" "$@"
    exit $?
  fi
fi

# 2. Auto-detect Trae executable on macOS and Linux
FOUND_EXE=""

# 2.1 macOS applications
for candidate in \
  "/Applications/Trae.app/Contents/MacOS/Trae" \
  "/Applications/Trae CN.app/Contents/MacOS/Trae CN" \
  "/Applications/TRAE SOLO CN.app/Contents/MacOS/TRAE SOLO CN" \
  "$HOME/Applications/Trae.app/Contents/MacOS/Trae" \
  "$HOME/Applications/Trae CN.app/Contents/MacOS/Trae CN"
do
  if [ -f "$candidate" ] && [ -x "$candidate" ]; then
    FOUND_EXE="$candidate"
    break
  fi
done

# 2.2 Linux paths
if [ -z "$FOUND_EXE" ]; then
  for candidate in \
    "$(command -v trae 2>/dev/null)" \
    "/usr/bin/trae" \
    "/usr/local/bin/trae" \
    "/opt/Trae/trae" \
    "/opt/trae/trae" \
    "$HOME/.local/share/trae/trae"
  do
    if [ -n "$candidate" ] && [ -f "$candidate" ] && [ -x "$candidate" ]; then
      FOUND_EXE="$candidate"
      break
    fi
  done
fi

# 3. Execute with detected Trae runtime if found
if [ -n "$FOUND_EXE" ]; then
  export ELECTRON_RUN_AS_NODE=1
  unset VSCODE_DEV
  "$FOUND_EXE" "$SCRIPT_PATH" "$@"
  exit $?
fi

echo "[ERROR] No suitable runtime (Node.js 18+ or Trae executable) found on this machine!"
echo "-------------------------------------------------------------------------"
echo "Please install Node.js 18+ (https://nodejs.org) or ensure Trae is properly installed."
echo "-------------------------------------------------------------------------"
exit 1