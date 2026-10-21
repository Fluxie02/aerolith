#!/bin/sh
# AEROLITH installer entry point. Runs the interactive installer from this
# checkout for the current user (no root). All options: ./install.sh --help
#   ./install.sh                       interactive install
#   ./install.sh --dry-run             show the plan, change nothing
#   ./install.sh --ai none --startup hyprland --yes   non-interactive
set -eu
here=$(cd "$(dirname "$0")" && pwd)
if ! command -v python3 >/dev/null 2>&1; then
  echo "AEROLITH's installer needs python3 (sudo pacman -S python)" >&2
  exit 1
fi
case "${1:-}" in
  -h|--help) exec python3 -I -B -c 'import sys; sys.path.insert(0, sys.argv[1]); from aerolith_install.cli import main; sys.exit(main(["install", "--help"]))' "$here/installer" ;;
esac
exec python3 -I -B -c 'import sys; sys.path.insert(0, sys.argv[1]); from aerolith_install.cli import main; sys.exit(main(sys.argv[2:]))' "$here/installer" install "$@"
