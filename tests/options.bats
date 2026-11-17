#!/usr/bin/env bats
load test_helper
setup() {
    setup_env
    write_config
    export CONFIG="$XDG_CONFIG_HOME/keshiki/keshiki.cfg" HERE="$REPO_ROOT" ICON="$REPO_ROOT/keshiki.png"
    export KESHIKI_YAD_LOG="$TEST_ROOT/options.log"
    cat >"$STUB_BIN/keshiki" <<'STUB'
#!/bin/bash
printf '%s\0' "$@" >"$KESHIKI_YAD_LOG"
printf '%s\n' "$KESHIKI_YAD_RESPONSE"
STUB
    chmod +x "$STUB_BIN/keshiki"
}
teardown() { teardown_env; }

@test "las opciones conservan valores y escriben configuración ejecutable" {
    export KESHIKI_YAD_RESPONSE='TRUE|TRUE|85|FALSE|TRUE|'
    run "$REPO_ROOT/keshiki-options"
    [ "$status" -eq 0 ]
    source "$CONFIG"
    [ "${view[0]}" = TRUE ]
    [ "${audio[0]}" = TRUE ]
    [ "${audio[1]}" = --audio=1 ]
    [ "${audio[2]}" = 85 ]
    [ "$systemtray" = FALSE ]
    [ "$below_desk" = TRUE ]
    [ "$opacity" = 1 ]
}

@test "la opacidad no descarta las demás opciones" {
    export KESHIKI_YAD_RESPONSE='TRUE|0.5|'
    run "$REPO_ROOT/keshiki-options" -o
    [ "$status" -eq 0 ]
    source "$CONFIG"
    [ "$opacity" = 0.5 ]
    [ "${audio[2]}" = 100 ]
    [ "$systemtray" = FALSE ]
}
