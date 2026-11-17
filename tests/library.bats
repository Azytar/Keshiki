#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
    write_config
    mkdir -p "$TEST_ROOT/videos/A" "$TEST_ROOT/videos/B"
    export DIRCONFIG="${XDG_CONFIG_HOME}/keshiki/"
}

teardown() {
    teardown_env
}

add() {
    run "$REPO_ROOT/keshiki-add" "$1"
    [ "$status" -eq 0 ]
}

@test "dos vídeos con el mismo nombre en carpetas distintas no colisionan" {
    echo a >"$TEST_ROOT/videos/A/intro.mp4"
    echo b >"$TEST_ROOT/videos/B/intro.mp4"

    add "$TEST_ROOT/videos/A/intro.mp4"
    add "$TEST_ROOT/videos/B/intro.mp4"

    count=$(find "${DIRCONFIG}desktops" -name '*.desktop' | wc -l)
    [ "$count" -eq 2 ]

    sources=$(grep -h '^X-Keshiki-Source=' "${DIRCONFIG}desktops/"*.desktop | sort)
    printf '%s\n' "$sources" | grep -qF "$TEST_ROOT/videos/A/intro.mp4"
    printf '%s\n' "$sources" | grep -qF "$TEST_ROOT/videos/B/intro.mp4"
}

@test "añadir vídeos homónimos en paralelo conserva ambas miniaturas" {
    echo a >"$TEST_ROOT/videos/A/intro.mp4"
    echo b >"$TEST_ROOT/videos/B/intro.mp4"
    "$REPO_ROOT/keshiki-add" "$TEST_ROOT/videos/A/intro.mp4" &
    a=$!
    "$REPO_ROOT/keshiki-add" "$TEST_ROOT/videos/B/intro.mp4" &
    b=$!
    wait "$a"
    wait "$b"
    [ "$(find "${DIRCONFIG}desktops" -name '*.desktop' | wc -l)" -eq 2 ]
    [ "$(find "${DIRCONFIG}resources" -name image.jpg | wc -l)" -eq 2 ]
}

@test "regenerar la misma entrada no crea duplicados" {
    echo a >"$TEST_ROOT/videos/A/intro.mp4"
    add "$TEST_ROOT/videos/A/intro.mp4"
    add "$TEST_ROOT/videos/A/intro.mp4"

    count=$(find "${DIRCONFIG}desktops" -name '*.desktop' | wc -l)
    [ "$count" -eq 1 ]
}

@test "el Exec de la entrada escapa correctamente una ruta con espacios" {
    video="$TEST_ROOT/videos/mi fondo animado.mp4"
    echo x >"$video"
    add "$video"

    entry=$(grep -lF "mi fondo animado" "${DIRCONFIG}desktops/"*.desktop | head -1)
    [ -n "$entry" ]
    exec_line=$(grep '^Exec=' "$entry")
    [ "$exec_line" = "Exec=bash \"$REPO_ROOT/keshiki-start\" \"$video\"" ]
}

@test "añadir una carpeta con espacios procesa todos los vídeos" {
    dir="$TEST_ROOT/videos/mis clips"
    mkdir -p "$dir"
    echo 1 >"$dir/uno.mp4"
    echo 2 >"$dir/dos con espacios.mp4"
    echo 3 >"$dir/nota.txt"

    add "$dir"

    count=$(find "${DIRCONFIG}desktops" -name '*.desktop' | wc -l)
    [ "$count" -eq 2 ]
    sources=$(grep -h '^X-Keshiki-Source=' "${DIRCONFIG}desktops/"*.desktop)
    printf '%s\n' "$sources" | grep -qF "uno.mp4"
    printf '%s\n' "$sources" | grep -qF "dos con espacios.mp4"
}

@test "una miniatura fallida recurre al icono del programa" {
    echo x >"$TEST_ROOT/videos/A/intro.mp4"
    KESHIKI_THUMB_FAIL=1 add "$TEST_ROOT/videos/A/intro.mp4"

    entry=$(grep -lF 'intro' "${DIRCONFIG}desktops/"*.desktop | head -1)
    icon=$(grep '^Icon=' "$entry" | cut -d'=' -f2-)
    [ -s "$icon" ]
    cmp -s "$icon" "$REPO_ROOT/keshiki.png"
}

@test "eliminar por índice quita solo la entrada elegida" {
    echo a >"$TEST_ROOT/videos/A/intro.mp4"
    echo b >"$TEST_ROOT/videos/B/promo.mp4"
    add "$TEST_ROOT/videos/A/intro.mp4"
    add "$TEST_ROOT/videos/B/promo.mp4"

    # El orden del listado es alfabético: intro va antes que promo.
    printf 'TRUE|1|icon|intro\n' >"$TEST_ROOT/yad-selection.txt"

    run "$REPO_ROOT/keshiki-remove"
    [ "$status" -eq 0 ]

    [ ! -e "${DIRCONFIG}desktops/intro.desktop" ] || [ ! -f "${DIRCONFIG}desktops/intro.desktop" ]
    remaining=$(find "${DIRCONFIG}desktops" -name '*.desktop' | wc -l)
    [ "$remaining" -eq 1 ]
    sources=$(grep -h '^X-Keshiki-Source=' "${DIRCONFIG}desktops/"*.desktop)
    printf '%s\n' "$sources" | grep -qF "promo.mp4"
}

@test "keshiki-cli -s inicia el wallpaper correspondiente al índice" {
    echo a >"$TEST_ROOT/videos/A/intro.mp4"
    echo b >"$TEST_ROOT/videos/B/promo.mp4"
    add "$TEST_ROOT/videos/A/intro.mp4"
    add "$TEST_ROOT/videos/B/promo.mp4"

    run "$REPO_ROOT/keshiki-cli" -l
    [ "$status" -eq 0 ]

    : >"$XWINWRAP_LOG"
    run "$REPO_ROOT/keshiki-cli" -s 2
    [ "$status" -eq 0 ]
    wait_for_log "$XWINWRAP_LOG"

    tr '\0' '\n' <"$XWINWRAP_LOG" | grep -Fxq -- "$TEST_ROOT/videos/B/promo.mp4"
}

@test "el selector YAD entrega archivos con espacios como argumentos separados" {
    export KESHIKI_FILE_A="$TEST_ROOT/videos/A/intro uno.mp4"
    export KESHIKI_FILE_B="$TEST_ROOT/videos/B/intro dos.mp4"
    echo a >"$KESHIKI_FILE_A"
    echo b >"$KESHIKI_FILE_B"
    cat >"$STUB_BIN/keshiki" <<'STUB'
#!/bin/bash
if [[ " $* " = *' --form '* ]]; then
    trap '' USR1
    YAD_PID=$$ bash -c Select_files
    printf '|\n'
elif [[ " $* " = *' --file '* ]]; then
    found=0
    for arg in "$@"; do [ "$arg" != $'--separator=\n' ] || found=1; done
    [ "$found" -eq 1 ] || exit 1
    printf '%s\n%s\n' "$KESHIKI_FILE_A" "$KESHIKI_FILE_B"
fi
STUB
    chmod +x "$STUB_BIN/keshiki"
    export HERE="$REPO_ROOT" ICON="$REPO_ROOT/keshiki.png" Color="color='#31E6F0'"
    run "$REPO_ROOT/keshiki-adding"
    [ "$status" -eq 0 ]
    [ "$(find "${DIRCONFIG}desktops" -name '*.desktop' | wc -l)" -eq 2 ]
    grep -qlF "$KESHIKI_FILE_A" "${DIRCONFIG}desktops/"*.desktop
    grep -qlF "$KESHIKI_FILE_B" "${DIRCONFIG}desktops/"*.desktop
}

@test "se limpian los archivos temporales al fallar una miniatura" {
    mkdir "$TEST_ROOT/t"
    export TMPDIR="$TEST_ROOT/t" KESHIKI_THUMB_FAIL=1
    echo x >"$TEST_ROOT/videos/A/intro.mp4"
    add "$TEST_ROOT/videos/A/intro.mp4"
    [ -z "$(find "$TMPDIR" -mindepth 1 -print -quit)" ]
}
