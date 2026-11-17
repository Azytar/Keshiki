#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
    chmod 700 "$RUNTIME"
    write_config
    mkdir -p "$TEST_ROOT/videos"
    cat >"$STUB_BIN/xwinwrap" <<'STUB'
#!/bin/bash
[ "${1:-}" != -h ] || exit 0
printf '%s\0' "$@" >> "$XWINWRAP_LOG"
if [ "${KESHIKI_TEST_PLAYER:-}" = 1 ]; then
    for arg in "$@"; do
        case $arg in --input-ipc-server=*) socket=${arg#*=} ;; esac
    done
    exec python3 "$STUB_BIN/fake-player.py" "$socket" "$TEST_ROOT/ipc.log"
fi
STUB
    cat >"$STUB_BIN/fake-player.py" <<'STUB'
import os, socket, sys, time
path, log = sys.argv[1:]
if os.environ.get('KESHIKI_TEST_NO_SOCKET'):
    time.sleep(30)
    sys.exit()
s = socket.socket(socket.AF_UNIX)
s.bind(path)
s.listen()
while True:
    conn, _ = s.accept()
    data = conn.recv(4096)
    with open(log, 'ab') as out:
        out.write(data)
    conn.close()
    if b'"quit"' in data:
        break
s.close()
STUB
    chmod +x "$STUB_BIN/xwinwrap"
    export TEST_ROOT STUB_BIN XWINWRAP_LOG KESHIKI_TEST_PLAYER=1
}

teardown() {
    "$REPO_ROOT/keshiki-cli" -f >/dev/null 2>&1 || true
    teardown_env
}

session_dir() {
    local record
    record=$(find "$RUNTIME" -name current -print -quit)
    [ -n "$record" ] || return 1
    read -r supervisor start name <"$record"
    SESSION_DIR="${record%/*}/$name"
}

wait_socket() {
    local i
    for ((i = 0; i < 100; i++)); do
        if session_dir && [ -S "$SESSION_DIR/mpv.sock" ]; then return 0; fi
        sleep 0.05
    done
    return 1
}

@test "rutas con espacios y guiones llegan intactas después de --" {
    video="$TEST_ROOT/videos/--mi fondo.mp4"
    echo fake >"$video"
    run "$REPO_ROOT/keshiki-start" "$video"
    [ "$status" -eq 0 ]
    wait_socket
    mapfile -d '' -t args <"$XWINWRAP_LOG"
    [ "${args[-2]}" = -- ]
    [ "${args[-1]}" = "$video" ]
}

@test "las opciones de URL preceden al separador de mpv" {
    run "$REPO_ROOT/keshiki-start" 'https://example.com/watch?v=abc'
    [ "$status" -eq 0 ]
    wait_socket
    mapfile -d '' -t args <"$XWINWRAP_LOG"
    [ "${args[-2]}" = -- ]
    [ "${args[-1]}" = 'https://example.com/watch?v=abc' ]
    printf '%s\n' "${args[@]}" | grep -q '^--ytdl-format='
}

@test "pausa y detención usan el socket propio y preservan un mpv ajeno" {
    video="$TEST_ROOT/videos/fondo.mp4"
    echo fake >"$video"
    bash -c 'exec -a mpv sleep 30' &
    foreign_pid=$!
    bash -c 'exec -a /tmp/another-app/mpv.bash sleep 30' &
    foreign_wrapper=$!
    "$REPO_ROOT/keshiki-start" "$video"
    wait_socket
    old_dir=$SESSION_DIR
    "$REPO_ROOT/keshiki-cli" --pause
    "$REPO_ROOT/keshiki-cli" -f
    grep -q '"cycle"' "$TEST_ROOT/ipc.log"
    grep -q '"quit"' "$TEST_ROOT/ipc.log"
    kill -0 "$foreign_pid"
    kill -0 "$foreign_wrapper"
    [ ! -e "$old_dir" ]
    kill "$foreign_pid"
    kill "$foreign_wrapper"
    wait "$foreign_pid" 2>/dev/null || true
    wait "$foreign_wrapper" 2>/dev/null || true
}

@test "sin IPC se detiene solo el proceso de la sesión" {
    video="$TEST_ROOT/videos/fondo.mp4"
    echo fake >"$video"
    export KESHIKI_TEST_NO_SOCKET=1
    bash -c 'exec -a mpv sleep 30' &
    foreign_pid=$!
    "$REPO_ROOT/keshiki-start" "$video"
    wait_for_log "$XWINWRAP_LOG"
    session_dir
    own_pid=$supervisor
    "$REPO_ROOT/keshiki-cli" -f
    ! kill -0 "$own_pid" 2>/dev/null
    kill -0 "$foreign_pid"
    kill "$foreign_pid"
    wait "$foreign_pid" 2>/dev/null || true
}

@test "una sesión sustituida limpia su socket y no comparte el nuevo" {
    video="$TEST_ROOT/videos/fondo.mp4"
    echo fake >"$video"
    "$REPO_ROOT/keshiki-start" "$video"
    wait_socket
    old_dir=$SESSION_DIR
    "$REPO_ROOT/keshiki-start" "$video"
    wait_socket
    [ "$old_dir" != "$SESSION_DIR" ]
    [ ! -e "$old_dir" ]
}

@test "un registro obsoleto no afecta a otro proceso" {
    video="$TEST_ROOT/videos/fondo.mp4"
    echo fake >"$video"
    "$REPO_ROOT/keshiki-start" "$video"
    wait_socket
    runtime=${SESSION_DIR%/*}
    "$REPO_ROOT/keshiki-cli" -f
    bash -c 'exec -a mpv sleep 30' &
    foreign_pid=$!
    mkdir "$runtime/session.STALE123"
    printf '%s 1 %s\n' "$foreign_pid" session.STALE123 >"$runtime/current"
    "$REPO_ROOT/keshiki-cli" -f
    kill -0 "$foreign_pid"
    [ ! -e "$runtime/session.STALE123" ]
    kill "$foreign_pid"
    wait "$foreign_pid" 2>/dev/null || true
}

@test "un socket obsoleto se elimina sin conectar a él" {
    video="$TEST_ROOT/videos/fondo.mp4"
    echo fake >"$video"
    "$REPO_ROOT/keshiki-start" "$video"
    wait_socket
    runtime=${SESSION_DIR%/*}
    "$REPO_ROOT/keshiki-cli" -f
    mkdir "$runtime/session.STALE123"
    python3 -c 'import socket,sys; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.close()' "$runtime/session.STALE123/mpv.sock"
    printf '99999999 1 %s\n' session.STALE123 >"$runtime/current"
    "$REPO_ROOT/keshiki-cli" -f
    [ ! -e "$runtime/session.STALE123" ]
}

@test "un XDG_RUNTIME_DIR inseguro usa una alternativa privada" {
    video="$TEST_ROOT/videos/fondo.mp4"
    echo fake >"$video"
    mkdir "$TEST_ROOT/t"
    chmod 700 "$TEST_ROOT/t"
    chmod 777 "$RUNTIME"
    export TMPDIR="$TEST_ROOT/t" DISPLAY=:98765
    "$REPO_ROOT/keshiki-start" "$video"
    for ((i = 0; i < 100; i++)); do
        record=$(find "$TMPDIR" -name current -print -quit)
        [ -z "$record" ] || break
        sleep 0.05
    done
    [ -n "$record" ]
    [ "$(stat -c %a "$TMPDIR/keshiki-$(id -u)")" = 700 ]
    [ -z "$(find "$RUNTIME" -name current -print -quit)" ]
}

@test "dos arranques simultáneos dejan una sola sesión activa" {
    video="$TEST_ROOT/videos/fondo.mp4"
    echo fake >"$video"
    "$REPO_ROOT/keshiki-start" "$video" &
    first=$!
    "$REPO_ROOT/keshiki-start" "$video" &
    second=$!
    wait "$first"
    wait "$second"
    wait_socket
    [ "$(find "$RUNTIME" -name current | wc -l)" -eq 1 ]
    [ "$(find "$RUNTIME" -name mpv.sock | wc -l)" -eq 1 ]
}

@test "un socket activo ajeno en una sesión obsoleta se conserva" {
    video="$TEST_ROOT/videos/fondo.mp4"
    echo fake >"$video"
    "$REPO_ROOT/keshiki-start" "$video"
    wait_socket
    runtime=${SESSION_DIR%/*}
    "$REPO_ROOT/keshiki-cli" -f
    mkdir "$runtime/session.FOREIGN1"
    python3 -c 'import socket,sys,time; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.listen(); time.sleep(30)' "$runtime/session.FOREIGN1/mpv.sock" &
    foreign=$!
    for ((i = 0; i < 100; i++)); do
        [ ! -S "$runtime/session.FOREIGN1/mpv.sock" ] || break
        sleep 0.05
    done
    printf '99999999 1 %s\n' session.FOREIGN1 >"$runtime/current"
    run "$REPO_ROOT/keshiki-cli" -f
    [ "$status" -ne 0 ]
    [ -S "$runtime/session.FOREIGN1/mpv.sock" ]
    kill -0 "$foreign"
    kill "$foreign"
    wait "$foreign" 2>/dev/null || true
    "$REPO_ROOT/keshiki-cli" -f
}

@test "pantalla completa y maximización completa pausan y reanudan" {
    video="$TEST_ROOT/videos/fondo.mp4"
    echo fake >"$video"
    export KESHIKI_STATE="$TEST_ROOT/window-state"
    printf '_NET_WM_STATE(ATOM) =\n' >"$KESHIKI_STATE"
    printf '#!/bin/bash\nprintf 100\\n\n' >"$STUB_BIN/xdotool"
    printf '#!/bin/bash\ncat "$KESHIKI_STATE"\n' >"$STUB_BIN/xprop"
    chmod +x "$STUB_BIN/xdotool" "$STUB_BIN/xprop"
    "$REPO_ROOT/keshiki-start" "$video"
    wait_socket
    printf '_NET_WM_STATE_FULLSCREEN\n' >"$KESHIKI_STATE"
    for ((i = 0; i < 100; i++)); do
        grep -q '"pause",true' "$TEST_ROOT/ipc.log" 2>/dev/null && break
        sleep 0.05
    done
    grep -q '"pause",true' "$TEST_ROOT/ipc.log"
    printf '_NET_WM_STATE(ATOM) =\n' >"$KESHIKI_STATE"
    for ((i = 0; i < 100; i++)); do
        grep -q '"pause",false' "$TEST_ROOT/ipc.log" 2>/dev/null && break
        sleep 0.05
    done
    grep -q '"pause",false' "$TEST_ROOT/ipc.log"
    : >"$TEST_ROOT/ipc.log"
    printf '_NET_WM_STATE_MAXIMIZED_HORZ _NET_WM_STATE_MAXIMIZED_VERT\n' >"$KESHIKI_STATE"
    for ((i = 0; i < 100; i++)); do
        grep -q '"pause",true' "$TEST_ROOT/ipc.log" 2>/dev/null && break
        sleep 0.05
    done
    grep -q '"pause",true' "$TEST_ROOT/ipc.log"
}

@test "las sesiones en pantallas diferentes se controlan por separado" {
    video="$TEST_ROOT/videos/fondo.mp4"
    echo fake >"$video"
    DISPLAY=:7201 "$REPO_ROOT/keshiki-start" "$video"
    DISPLAY=:7202 "$REPO_ROOT/keshiki-start" "$video"
    for ((i = 0; i < 100; i++)); do
        [ "$(find "$RUNTIME" -name mpv.sock | wc -l)" -eq 2 ] && break
        sleep 0.05
    done
    [ "$(find "$RUNTIME" -name mpv.sock | wc -l)" -eq 2 ]
    DISPLAY=:7201 "$REPO_ROOT/keshiki-cli" -f
    [ "$(find "$RUNTIME" -name mpv.sock | wc -l)" -eq 1 ]
    DISPLAY=:7202 "$REPO_ROOT/keshiki-cli" -f
    [ "$(find "$RUNTIME" -name mpv.sock | wc -l)" -eq 0 ]
}

@test "sin XDG_RUNTIME_DIR se crea un directorio privado" {
    video="$TEST_ROOT/videos/fondo.mp4"
    echo fake >"$video"
    mkdir "$TEST_ROOT/t"
    chmod 700 "$TEST_ROOT/t"
    export TMPDIR="$TEST_ROOT/t" DISPLAY=:98766
    unset XDG_RUNTIME_DIR
    "$REPO_ROOT/keshiki-start" "$video"
    for ((i = 0; i < 100; i++)); do
        record=$(find "$TMPDIR" -name current -print -quit)
        [ -z "$record" ] || break
        sleep 0.05
    done
    [ -n "$record" ]
    [ "$(stat -c %a "$TMPDIR/keshiki-$(id -u)")" = 700 ]
    "$REPO_ROOT/keshiki-cli" -f
    [ -z "$(find "$TMPDIR" -name mpv.sock -print -quit)" ]
}
