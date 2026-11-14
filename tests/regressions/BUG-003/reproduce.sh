#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
lab=$(mktemp -d "$root/.audit-bug-003.XXXXXX")
trap 'rm -rf -- "$lab"' EXIT
if [[ ${1:-} == --baseline ]]; then
    git -C "$root" show 45a1e7e8793e97c0bd79f3953e9bda454ddae329:keshiki-add > "$lab/keshiki-add"
    git -C "$root" show 45a1e7e8793e97c0bd79f3953e9bda454ddae329:keshiki-cli > "$lab/keshiki-cli"
else
    cp -- "$root/keshiki-add" "$lab/keshiki-add"
    cp -- "$root/keshiki-cli" "$lab/keshiki-cli"
fi
add_script="$lab/keshiki-add"
cli_source="$lab/keshiki-cli"
program="$lab/program location"
mkdir -p -- "$program" "$lab/home/.config/keshiki/desktops" \
    "$lab/home/.local/share/applications"
cat > "$program/keshiki-start" <<'STUB'
#!/usr/bin/env bash
printf '%s\0' "$@" > "$AUDIT_ARGV"
STUB
chmod +x "$program/keshiki-start"
files=(
    "$lab/My Wallpaper.mp4"
    "$lab/fondo (final).mp4"
    "$lab/fondo'original.mp4"
    "$lab/fondo\$especial.mp4"
    "$lab/vídeo_日本語.mp4"
    "$lab/--video.mp4"
    "$lab/100% video.mp4"
    "$lab/quote\"name.mp4"
    "$lab/tick\`name.mp4"
    "$lab/back\\slash.mp4"
    "$lab/pipe|name.mp4"
)
for i in "${!files[@]}"; do
    video=${files[i]}
    : > "$video"
    HOME="$lab/home" DIRCONFIG="$lab/home/.config/keshiki/" HERE="$program" \
        ICON="$root/keshiki.png" bash "$add_script" "$video" \
        > "$lab/add.log" 2>&1
    base=${video##*/}
    base=${base%.mp4}
    base=${base//[=,.]/}
    base=${base// /_}
    desktop="$lab/home/.config/keshiki/desktops/${base}.desktop"
    if [[ ! -f $desktop ]]; then
        cat "$lab/add.log" >&2
        printf 'FAIL: generated entry missing for %q\n' "$video" >&2
        exit 2
    fi
    desktop-file-validate "$desktop"
    cp -- "$desktop" "$lab/home/.local/share/applications/audit-$i.desktop"
    argv_file="$lab/gtk-argv-$i.bin"
    if ! XDG_DATA_HOME="$lab/home/.local/share" AUDIT_ARGV="$argv_file" \
        gtk-launch "audit-$i" > "$lab/gtk-launch-$i.log" 2>&1; then
        cat "$lab/gtk-launch-$i.log" >&2
        exit 2
    fi
    for _ in {1..100}; do
        [[ -f $argv_file ]] && break
        sleep 0.01
    done
    if [[ ! -f $argv_file ]]; then
        cat "$lab/gtk-launch-$i.log" >&2
        grep '^Exec=' "$desktop" >&2
        printf 'FAIL: launcher did not invoke capture stub for %q\n' "$video" >&2
        exit 2
    fi
    mapfile -d '' -t argv < "$argv_file"
    if [[ ${#argv[@]} != 1 || ${argv[0]} != "$video" ]]; then
        printf 'FAIL: desktop launcher did not preserve %q as one argument\n' \
            "$video" >&2
        printf 'received:' >&2
        printf ' <%q>' "${argv[@]}" >&2
        printf '\n' >&2
        exit 1
    fi
done
for i in "${!files[@]}"; do
    cli_home="$lab/cli home $i"
    cli_bin="$lab/cli bin $i"
    mkdir -p -- "$cli_home/.config/keshiki/desktops" "$cli_bin"
    HOME="$cli_home" DIRCONFIG="$cli_home/.config/keshiki/" HERE="$program" \
        ICON="$root/keshiki.png" bash "$add_script" "${files[i]}" \
        > "$lab/cli-add.log" 2>&1
    sed "s|/tmp/keshiki_list_wall.txt|$lab/cli-list-$i|;s|/tmp/keshiki_tmp_list|$lab/cli-tmp-list-$i|" \
        "$cli_source" > "$cli_bin/keshiki-cli"
    chmod +x "$cli_bin/keshiki-cli"
    cp -- "$program/keshiki-start" "$cli_bin/keshiki-start"
    cli_argv="$lab/cli-argv-$i.bin"
    HOME="$cli_home" USER=audit bash "$cli_bin/keshiki-cli" -l > "$lab/cli-list.log"
    HOME="$cli_home" USER=audit AUDIT_ARGV="$cli_argv" \
        bash "$cli_bin/keshiki-cli" -s 1 > "$lab/cli-start.log"
    mapfile -d '' -t argv < "$cli_argv"
    if [[ ${#argv[@]} != 1 || ${argv[0]} != "${files[i]}" ]]; then
        printf 'FAIL: CLI selection did not restore one full path argument: %q\n' \
            "${files[i]}" >&2
        printf 'received:' >&2
        printf ' <%q>' "${argv[@]}" >&2
        printf '\n' >&2
        exit 1
    fi
done
printf 'PASS: generated desktop entry is valid\n'
