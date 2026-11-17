#!/bin/bash
set -eu
app=$1
video=$2
foreign_gui=''
foreign_tray=''
gui=''
tray=''
cleanup() {
    "$app/keshiki-cli" --close-gui >/dev/null 2>&1 || :
    "$app/keshiki-cli" --close-tray >/dev/null 2>&1 || :
    "$app/keshiki-cli" -f >/dev/null 2>&1 || :
    [ -z "$foreign_gui" ] || kill "$foreign_gui" 2>/dev/null || :
    [ -z "$foreign_tray" ] || kill "$foreign_tray" 2>/dev/null || :
    [ -z "$gui" ] || wait "$gui" 2>/dev/null || :
    [ -z "$tray" ] || wait "$tray" 2>/dev/null || :
}
trap cleanup EXIT
bash -c 'exec -a keshiki sleep 30' &
foreign_gui=$!
bash -c 'exec -a yadsystray sleep 30' &
foreign_tray=$!
"$app/keshiki.bash" >"$XDG_RUNTIME_DIR/gui.log" 2>&1 &
gui=$!
for ((i = 0; i < 100; i++)); do
    record=$(find "$XDG_RUNTIME_DIR" -name gui.pid -print -quit)
    [ -z "$record" ] || break
    sleep 0.05
done
[ -n "$record" ]
sleep 0.5
if ! kill -0 "$gui"; then
    cat "$XDG_RUNTIME_DIR/gui.log" >&2
    exit 1
fi
"$app/keshiki-start" "$video"
for ((i = 0; i < 100; i++)); do
    socket=$(find "$XDG_RUNTIME_DIR" -name mpv.sock -print -quit)
    [ -z "$socket" ] || break
    sleep 0.05
done
[ -S "$socket" ]
window=$(xdotool search --name '^Keshiki$' | tail -1)
[ -n "$window" ]
eval "$(xdotool getwindowgeometry --shell "$window")"
xdotool windowraise "$window"
xdotool windowfocus "$window"
xdotool mousemove --window "$window" "$((WIDTH / 2))" "$((HEIGHT - 20))" click 1
for ((i = 0; i < 100; i++)); do
    [ -S "$socket" ] || break
    sleep 0.05
done
[ ! -S "$socket" ]
"$app/keshiki-cli" --toggle-gui
wait "$gui"
gui=''
kill -0 "$foreign_gui"
kill -0 "$foreign_tray"
"$app/keshiki-cli" --close-tray
kill -0 "$foreign_tray"
"$app/keshiki-systray" >"$XDG_RUNTIME_DIR/tray.log" 2>&1 &
tray=$!
for ((i = 0; i < 100; i++)); do
    record=$(find "$XDG_RUNTIME_DIR" -name tray.pid -print -quit)
    [ -z "$record" ] || break
    sleep 0.05
done
[ -n "$record" ]
sleep 0.5
if ! kill -0 "$tray"; then
    cat "$XDG_RUNTIME_DIR/tray.log" >&2
    exit 1
fi
"$app/keshiki-cli" --close-tray
wait "$tray"
tray=''
kill -0 "$foreign_tray"
