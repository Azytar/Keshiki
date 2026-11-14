#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
baseline=45a1e7e8793e97c0bd79f3953e9bda454ddae329
lab=$(mktemp -d "$root/.audit-bug-004.XXXXXX")
trap 'rm -rf -- "$lab"' EXIT
mkdir -p -- "$lab/home/.config/keshiki/desktops" "$lab/one" "$lab/two"
if [[ ${1:-} == --baseline ]]; then
    git -C "$root" show "$baseline:keshiki-add" > "$lab/keshiki-add"
else
    cp -- "$root/keshiki-add" "$lab/keshiki-add"
fi
chmod +x "$lab/keshiki-add"
: > "$lab/one/Scene.mp4"
: > "$lab/two/Scene.mp4"

for _ in 1 2; do
    for video in "$lab/one/Scene.mp4" "$lab/two/Scene.mp4"; do
        HOME="$lab/home" DIRCONFIG="$lab/home/.config/keshiki/" \
            HERE="$root" ICON="$root/keshiki.png" \
            bash "$lab/keshiki-add" "$video" > "$lab/add.log" 2>&1
    done
done

shopt -s nullglob
entries=("$lab/home/.config/keshiki/desktops/"*.desktop)
if [[ ${#entries[@]} != 2 ]]; then
    printf 'FAIL: expected 2 distinct registrations; found %d\n' \
        "${#entries[@]}" >&2
    printf 'remaining entry: ' >&2
    sed -n 's/^Exec=//p' "${entries[0]}" >&2
    exit 1
fi

legacy_home="$lab/legacy-home"
legacy_video="$lab/legacy/Scene.mp4"
mkdir -p -- "$legacy_home/.config/keshiki/desktops" "$lab/legacy"
: > "$legacy_video"
cat > "$legacy_home/.config/keshiki/desktops/Scene.desktop" <<EOF
[Desktop Entry]
Name=Scene
Exec=$root/keshiki-start '$legacy_video'
Type=Application
EOF
HOME="$legacy_home" DIRCONFIG="$legacy_home/.config/keshiki/" \
    HERE="$root" ICON="$root/keshiki.png" \
    bash "$lab/keshiki-add" "$legacy_video" > "$lab/legacy-add.log" 2>&1
legacy_entries=("$legacy_home/.config/keshiki/desktops/"*.desktop)
if [[ ${#legacy_entries[@]} != 1 ]]; then
    printf 'FAIL: re-adding a legacy entry created a duplicate\n' >&2
    exit 1
fi
printf 'PASS: both same-basename videos remain registered\n'
