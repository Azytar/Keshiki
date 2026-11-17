#!/usr/bin/env bats
load test_helper
setup() {
    setup_env
    write_config
}
teardown() { teardown_env; }

@test "las entradas .desktop escapan y entregan rutas especiales a la aplicación" {
    command -v gio >/dev/null || skip 'gio no disponible'
    command -v desktop-file-validate >/dev/null || skip 'desktop-file-validate no disponible'
    app="$TEST_ROOT/app \$cash % \"quote\""
    mkdir -p "$app" "$TEST_ROOT/videos"
    cp "$REPO_ROOT/keshiki-add" "$REPO_ROOT/keshiki.png" "$app/"
    cat >"$app/keshiki-start" <<'STUB'
#!/bin/bash
printf '%s\0' "$@" >"$KESHIKI_DESKTOP_LOG"
STUB
    chmod +x "$app/keshiki-start"
    video="$TEST_ROOT/videos/\$cash % \"quote\" \\slash.mp4"
    printf x >"$video"
    export KESHIKI_DESKTOP_LOG="$TEST_ROOT/desktop.log"
    run "$app/keshiki-add" "$video"
    [ "$status" -eq 0 ]
    desk=$(find "$XDG_CONFIG_HOME/keshiki/desktops" -name '*.desktop' -print -quit)
    run desktop-file-validate "$desk"
    [ "$status" -eq 0 ]
    run xvfb-run -a gio launch "$desk"
    [ "$status" -eq 0 ]
    wait_for_log "$KESHIKI_DESKTOP_LOG"
    IFS= read -r -d '' result <"$KESHIKI_DESKTOP_LOG"
    [ "$result" = "$video" ]
}
