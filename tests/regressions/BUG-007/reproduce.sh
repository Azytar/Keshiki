#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
lab=$(mktemp -d "$root/.audit-bug-007.XXXXXX")
trap 'rm -rf -- "$lab"' EXIT
mkdir -p -- "$lab/bin" "$lab/home/.config/keshiki/desktops"
if [[ ${1:-} == --baseline ]]; then
    git -C "$root" show 45a1e7e8793e97c0bd79f3953e9bda454ddae329:keshiki-remove > "$lab/keshiki-remove"
else
    cp -- "$root/keshiki-remove" "$lab/keshiki-remove"
fi
sed -e "s|/tmp/keshiki_final.lis|$lab/final.lis|" \
    -e "s|/tmp/keshiki_remove.lis|$lab/remove.lis|" \
    "$lab/keshiki-remove" > "$lab/keshiki-remove.local"
mv -- "$lab/keshiki-remove.local" "$lab/keshiki-remove"
cat > "$lab/bin/yad" <<'STUB'
#!/usr/bin/env bash
printf '%s\0' "$@" > "$AUDIT_YAD_ARGV"
STUB
chmod +x "$lab/bin/yad" "$lab/keshiki-remove"
cat > "$lab/home/.config/keshiki/desktops/My Wallpaper.desktop" <<EOF
[Desktop Entry]
Name=My Wallpaper
Icon=$lab/home/.config/keshiki/resources/My Wallpaper/image.jpg
Type=Application
EOF
mkdir -p -- "$lab/home/.config/keshiki/resources/My Wallpaper"
restart(){ :; }
export -f restart
HOME="$lab/home" DIRCONFIG="$lab/home/.config/keshiki/" \
    ICON="$root/keshiki.png" LANG=en_US.UTF-8 PATH="$lab/bin:$PATH" \
    AUDIT_YAD_ARGV="$lab/yad-argv.bin" bash "$lab/keshiki-remove" \
    > "$lab/remove.log" 2>&1
mapfile -d '' -t argv < "$lab/yad-argv.bin"
found=false
for arg in "${argv[@]}"; do
    [[ $arg == 'My Wallpaper' ]] && found=true
done
if [[ $found != true ]]; then
    printf 'FAIL: YAD did not receive My Wallpaper as one argument\n' >&2
    exit 1
fi
printf 'PASS: wallpaper names containing spaces remain one argument\n'
