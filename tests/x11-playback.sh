#!/bin/bash
set -eu
app=$1
video=$2
cleanup() { "$app/keshiki-cli" -f >/dev/null 2>&1 || :; }
trap cleanup EXIT
"$app/keshiki-start" "$video"
record=''
for ((i = 0; i < 200; i++)); do
    record=$(find "$XDG_RUNTIME_DIR" -name current -print -quit)
    if [ -n "$record" ]; then
        read -r _ _ name <"$record"
        session_dir="${record%/*}/$name"
        [ ! -S "$session_dir/mpv.sock" ] || break
    fi
    sleep 0.05
done
[ -n "$record" ] && [ -S "$session_dir/mpv.sock" ] && [ -f "$session_dir/mpv.pid" ] || {
    echo 'mpv IPC socket did not appear' >&2
    exit 1
}
query_pause() {
    printf '%s\n' '{"command":["get_property","pause"]}' | socat -T 2 - "UNIX-CONNECT:$session_dir/mpv.sock"
}
query_pause | grep -q '"data":false'
"$app/keshiki-cli" --pause
query_pause | grep -q '"data":true'
"$app/keshiki-cli" --pause
query_pause | grep -q '"data":false'
"$app/keshiki-cli" -f
if [ -e "$session_dir" ]; then
    ls -la "$session_dir" >&2
    exit 1
fi
"$app/keshiki-start" "$video"
for ((i = 0; i < 200; i++)); do
    record=$(find "$XDG_RUNTIME_DIR" -name current -print -quit)
    if [ -n "$record" ]; then
        read -r supervisor _ name <"$record"
        session_dir="${record%/*}/$name"
        [ ! -S "$session_dir/mpv.sock" ] || break
    fi
    sleep 0.05
done
[ -S "$session_dir/mpv.sock" ] && [ -f "$session_dir/mpv.pid" ]
read -r player _ <"$session_dir/mpv.pid"
kill -KILL "$supervisor"
"$app/keshiki-cli" -f
[ ! -e "$session_dir" ]
if kill -0 "$player" 2>/dev/null; then exit 1; fi
"$app/keshiki-start" "$video"
for ((i = 0; i < 200; i++)); do
    record=$(find "$XDG_RUNTIME_DIR" -name current -print -quit)
    if [ -n "$record" ]; then
        read -r supervisor _ name <"$record"
        session_dir="${record%/*}/$name"
        [ ! -S "$session_dir/mpv.sock" ] || break
    fi
    sleep 0.05
done
[ -S "$session_dir/mpv.sock" ] && [ -f "$session_dir/mpv.pid" ]
read -r player _ <"$session_dir/mpv.pid"
kill -KILL "$supervisor"
rm -f -- "$session_dir/mpv.sock"
"$app/keshiki-cli" -f
[ ! -e "$session_dir" ]
if kill -0 "$player" 2>/dev/null; then exit 1; fi
