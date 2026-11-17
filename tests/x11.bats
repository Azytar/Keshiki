#!/usr/bin/env bats
load test_helper
setup() {
    setup_env
    chmod 700 "$RUNTIME"
    write_config
}
teardown() { teardown_env; }

@test "mpv real reproduce y responde al IPC bajo Xvfb" {
    for cmd in xvfb-run xwinwrap mpv ffmpeg socat; do
        command -v "$cmd" >/dev/null || skip "$cmd no disponible"
    done
    export PATH=/usr/local/bin:/usr/bin:/bin
    video="$TEST_ROOT/fondo con espacios.mp4"
    run ffmpeg -loglevel error -f lavfi -i color=c=blue:s=160x90:r=10 -t 2 -c:v mpeg4 "$video"
    [ "$status" -eq 0 ]
    run "$REPO_ROOT/install.sh"
    [ "$status" -eq 0 ]
    mkdir -p "$HOME/.config/mpv"
    printf 'vo=x11\nhwdec=no\n' >"$HOME/.config/mpv/mpv.conf"
    run xvfb-run -a -s '-screen 0 1280x800x24' bash "$REPO_ROOT/tests/x11-playback.sh" "$XDG_DATA_HOME/keshiki" "$video"
    [ "$status" -eq 0 ]
}

@test "la GUI real se abre y se cierra sin afectar procesos homónimos" {
    for cmd in xvfb-run yad xdotool ffmpeg mpv xwinwrap; do
        command -v "$cmd" >/dev/null || skip "$cmd no disponible"
    done
    export PATH=/usr/local/bin:/usr/bin:/bin
    run "$REPO_ROOT/install.sh"
    [ "$status" -eq 0 ]
    video="$TEST_ROOT/gui-video.mp4"
    run ffmpeg -loglevel error -f lavfi -i color=c=blue:s=160x90:r=10 -t 2 -c:v mpeg4 "$video"
    [ "$status" -eq 0 ]
    mkdir -p "$HOME/.config/mpv"
    printf 'vo=x11\nhwdec=no\n' >"$HOME/.config/mpv/mpv.conf"
    run xvfb-run -a -s '-screen 0 1280x800x24' bash -x "$REPO_ROOT/tests/x11-gui.sh" "$XDG_DATA_HOME/keshiki" "$video"
    [ "$status" -eq 0 ]
}
