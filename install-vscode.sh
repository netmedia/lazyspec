#!/bin/sh
# LazySpec - install-vscode.sh: installs vscode/lazyspec.vsix in every editor built on VS Code found
# (VS Code, VS Code Insiders, Cursor, Windsurf, VSCodium). macOS and Linux; on Windows: install-vscode.exe.
#   ./install-vscode.sh              every editor found
#   ./install-vscode.sh cursor       only these (code, code-insiders, cursor, windsurf, codium)
#   ./install-vscode.sh --uninstall  removes it (netmedia.lazyspec)
# After a git pull: run it again to update the extension.
# Netmedia | https://netmedia.agency | https://github.com/netmedia/lazyspec

here=$(cd "$(dirname "$0")" && pwd)
vsix="$here/vscode/lazyspec.vsix"
uninstall=0
only=""
for a in "$@"; do
  case "$a" in
    --uninstall|-u) uninstall=1 ;;
    -h|--help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}/  /'; exit 0 ;;
    *) only="$only $a" ;;
  esac
done
[ $uninstall = 1 ] || [ -f "$vsix" ] || { echo "  ERROR: $vsix isn't there (cd vscode; npm install; npm run package)."; exit 1; }

found=0; failed=0
for cmd in code code-insiders cursor windsurf codium; do
  [ -n "$only" ] && case " $only " in *" $cmd "*) ;; *) continue ;; esac
  case $cmd in
    code) app="Visual Studio Code"; name="VS Code" ;;
    code-insiders) app="Visual Studio Code - Insiders"; name="VS Code Insiders" ;;
    cursor) app="Cursor"; name="Cursor" ;;
    windsurf) app="Windsurf"; name="Windsurf" ;;
    codium) app="VSCodium"; name="VSCodium" ;;
  esac
  exe=$(command -v "$cmd" 2>/dev/null)
  [ -z "$exe" ] && [ -x "/Applications/$app.app/Contents/Resources/app/bin/$cmd" ] && exe="/Applications/$app.app/Contents/Resources/app/bin/$cmd"
  [ -z "$exe" ] && { [ -n "$only" ] && echo "  - $name: not found"; continue; }
  found=$((found + 1))
  if [ $uninstall = 1 ]; then out=$("$exe" --uninstall-extension netmedia.lazyspec 2>&1)
  else out=$("$exe" --install-extension "$vsix" --force 2>&1); fi
  if [ $? = 0 ]; then echo "  ✓ $name"; else failed=$((failed + 1)); echo "  ✗ $name: $out"; fi
done
if [ $found = 0 ]; then
  echo "  No VS Code, Cursor, Windsurf or VSCodium found. In the editor: Extensions: Install from VSIX... and pick vscode/lazyspec.vsix."
  exit 1
fi
[ $uninstall = 1 ] || [ $failed != 0 ] || echo "  Done: reload the editor's window; the checklist icon in the activity bar opens LazySpec."
[ $failed = 0 ]
