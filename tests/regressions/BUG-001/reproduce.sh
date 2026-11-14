#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
lab=$(mktemp -d "$root/.audit-bug-001.XXXXXX")
trap 'rm -rf -- "$lab"' EXIT

installer="$root/install.sh"
if [[ ${1:-} == --baseline ]]; then
    git -C "$root" show 45a1e7e8793e97c0bd79f3953e9bda454ddae329:install.sh > "$lab/install.sh"
    installer="$lab/install.sh"
fi
install_dir=$(sed -n 's/^INSTALL_DIR="\([^"]*\)"/\1/p' "$installer")
exec_value=$(sed -n '/^cat <<EOF > "\$DESKTOP_FILE"/,/^EOF$/ { s/^Exec=//p; }' "$installer")
icon_value=$(sed -n '/^cat <<EOF > "\$DESKTOP_FILE"/,/^EOF$/ { s/^Icon=//p; }' "$installer")
exec_value=${exec_value//\$\{INSTALL_DIR\}/$install_dir}
icon_value=${icon_value//\$\{INSTALL_DIR\}/$install_dir}

if [[ -z $install_dir || -z $exec_value || -z $icon_value ]]; then
    printf 'FAIL: could not read installer paths\n' >&2
    exit 2
fi

mkdir -p -- "$lab$install_dir"
printf '#!/bin/sh\nexit 0\n' > "$lab$install_dir/keshiki.bash"
chmod +x "$lab$install_dir/keshiki.bash"
cat > "$lab/keshiki.desktop" <<EOF
[Desktop Entry]
Version=1.3
Name=Keshiki
Comment=Audit fixture
Exec=$lab$exec_value
Icon=$lab$icon_value
Type=Application
Categories=Utility;
Terminal=false
EOF

desktop-file-validate "$lab/keshiki.desktop"
if [[ $exec_value != "$install_dir/keshiki.bash" ||
      $icon_value != "$install_dir/keshiki.png" ]]; then
    printf 'FAIL: desktop paths differ from INSTALL_DIR (Exec=%s, Icon=%s, install=%s)\n' \
        "$exec_value" "$icon_value" "$install_dir" >&2
    exit 1
fi
[[ -x $lab$exec_value ]]
printf 'PASS: desktop Exec target matches the installed executable\n'
