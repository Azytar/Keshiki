#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
lab=$(mktemp -d "$root/.audit-bug-002.XXXXXX")
trap 'rm -rf -- "$lab"' EXIT
mkdir -p -- "$lab/bin" "$lab/home/.config/keshiki"
if [[ ${1:-} == --baseline ]]; then
    git -C "$root" show 45a1e7e8793e97c0bd79f3953e9bda454ddae329:keshiki-start > "$lab/keshiki-start"
else
    cp -- "$root/keshiki-start" "$lab/keshiki-start"
fi
chmod +x "$lab/keshiki-start"

cat > "$lab/bin/xwinwrap" <<'STUB'
#!/usr/bin/env bash
while (($#)) && [[ $1 != -- ]]; do
    shift
done
[[ $# -gt 1 ]] || exit 64
shift
command=$1
shift
"$command" "$@"
STUB
cat > "$lab/bin/mpv.bash" <<'STUB'
#!/usr/bin/env bash
printf '%s\0' "$@" > "$AUDIT_MPV_ARGV"
STUB
cat > "$lab/keshiki-cli" <<'STUB'
#!/bin/sh
exit 0
STUB
cat > "$lab/bin/pidof" <<'STUB'
#!/bin/sh
exit 1
STUB
chmod +x "$lab/bin/"* "$lab/keshiki-cli"
printf 'view=(TRUE )\naudio=(TRUE --no-audio 100)\nopacity=1\n' \
    > "$lab/home/.config/keshiki/keshiki.cfg"

files=(
    "$lab/My Fondo.mp4"
    "$lab/fondo (final).mp4"
    "$lab/fondo'original.mp4"
    "$lab/fondo\$especial.mp4"
    "$lab/vídeo_日本語.mp4"
    "$lab/--video.mp4"
)
for file in "${files[@]}"; do
    : > "$file"
done

for file in "${files[@]}"; do
    argv_file="$lab/argv.bin"
    rm -f -- "$argv_file"
    HOME="$lab/home" USER=audit PATH="$lab/bin:$PATH" AUDIT_MPV_ARGV="$argv_file" \
        bash "$lab/keshiki-start" "$file" > "$lab/start.log" 2>&1
    for _ in {1..100}; do
        [[ -s $argv_file ]] && break
        sleep 0.01
    done
    if [[ ! -s $argv_file ]]; then
        printf 'FAIL: xwinwrap stub was not called for %q\n' "$file" >&2
        cat "$lab/start.log" >&2
        exit 2
    fi
    mapfile -d '' -t argv < "$argv_file"
    if [[ ${argv[-1]} != "$file" ]]; then
        printf 'FAIL: path did not arrive as one argument: %q; final argv=%q\n' \
            "$file" "${argv[-1]}" >&2
        exit 1
    fi
done
url='https://www.youtube.com/watch?v=audit123'
argv_file="$lab/url-argv.bin"
HOME="$lab/home" USER=audit PATH="$lab/bin:$PATH" AUDIT_MPV_ARGV="$argv_file" \
    bash "$lab/keshiki-start" "$url" > "$lab/url-start.log" 2>&1
for _ in {1..100}; do
    [[ -s $argv_file ]] && break
    sleep 0.01
done
if [[ ! -s $argv_file ]]; then
    cat "$lab/url-start.log" >&2
    printf 'FAIL: xwinwrap stub was not called for URL\n' >&2
    exit 2
fi
mapfile -d '' -t argv < "$argv_file"
url_found=false
for arg in "${argv[@]}"; do
    [[ $arg == "$url" ]] && url_found=true
done
if [[ $url_found != true ]]; then
    printf 'FAIL: URL did not arrive as one argument: %q\n' "$url" >&2
    exit 1
fi
printf 'PASS: all local paths and the URL arrived as single arguments\n'
