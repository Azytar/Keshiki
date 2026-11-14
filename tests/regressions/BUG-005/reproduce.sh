#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
lab=$(mktemp -d "$root/.audit-bug-005.XXXXXX")
trap 'rm -rf -- "$lab"' EXIT
mkdir -p -- "$lab/bin" "$lab/home/.config/keshiki"
if [[ ${1:-} == --baseline ]]; then
    git -C "$root" show 45a1e7e8793e97c0bd79f3953e9bda454ddae329:keshiki-start > "$lab/keshiki-start"
else
    cp -- "$root/keshiki-start" "$lab/keshiki-start"
fi
cat > "$lab/keshiki-cli" <<'STUB'
#!/bin/sh
exit 0
STUB
cat > "$lab/bin/xwinwrap" <<'STUB'
#!/bin/sh
exit 0
STUB
cat > "$lab/bin/pidof" <<'STUB'
#!/bin/sh
exit 1
STUB
chmod +x "$lab/keshiki-start" "$lab/keshiki-cli" "$lab/bin/"*

short="$lab/video.mp4"
long="$short.bak"
: > "$short"
: > "$long"
printf '%s\n' "$long" > "$lab/home/.config/keshiki/last_wallpaper.txt"
printf 'view=(TRUE )\naudio=(TRUE --no-audio 100)\nopacity=1\nbelow_desk=FALSE\n' \
    > "$lab/home/.config/keshiki/keshiki.cfg"
HOME="$lab/home" USER=audit PATH="$lab/bin:$PATH" \
    bash "$lab/keshiki-start" "$short" > "$lab/start.log" 2>&1

saved=$(< "$lab/home/.config/keshiki/last_wallpaper.txt")
if [[ $saved != "$short" ]]; then
    printf 'FAIL: selected %q but restore state remains %q\n' "$short" "$saved" >&2
    exit 1
fi
printf 'PASS: restore state matches the selected path exactly\n'
