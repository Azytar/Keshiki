#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
}

teardown() {
    teardown_env
}

run_user_install() {
    cd "$TEST_ROOT" && run "$REPO_ROOT/install.sh"
}

mark_previous_version() {
    local marker=$1 digest
    printf '%s\n' "$marker" >"$app_dir/keshiki.bash"
    read -r digest _ < <(sha256sum "$app_dir/keshiki.bash")
    sed -i "s/^file keshiki.bash .*/file keshiki.bash $digest/" "$app_dir/.keshiki-manifest"
}

@test "instalación de usuario sin privilegios coloca binario, entrada y manifiesto" {
    run_user_install
    [ "$status" -eq 0 ]

    app_dir="$TEST_HOME/.local/share/keshiki"
    [ -x "$app_dir/keshiki.bash" ]
    [ -x "$app_dir/keshiki-start" ]
    [ -x "$app_dir/keshiki-cli" ]
    [ -x "$app_dir/bin/mpv.bash" ]
    [ -L "$app_dir/bin/keshiki" ]

    [ -L "$TEST_HOME/.local/bin/keshiki" ]
    target="$(readlink -f "$TEST_HOME/.local/bin/keshiki")"
    [ "$target" = "$app_dir/keshiki.bash" ]

    desktop="$TEST_HOME/.local/share/applications/keshiki.desktop"
    [ -f "$desktop" ]
    grep -q '^Type=Application' "$desktop"
    grep -qF "Exec=bash \"$app_dir/keshiki.bash\"" "$desktop"
    grep -qF "Icon=$app_dir/keshiki.png" "$desktop"

    [ -f "$app_dir/.keshiki-manifest" ]
}

@test "la entrada .desktop escapa rutas con espacios según Desktop Entry" {
    run_user_install
    [ "$status" -eq 0 ]

    desktop="$TEST_HOME/.local/share/applications/keshiki.desktop"
    exec_line=$(grep '^Exec=' "$desktop")
    # El directorio de instalación contiene espacios y debe ir entre comillas.
    [ "$exec_line" = "Exec=bash \"$TEST_HOME/.local/share/keshiki/keshiki.bash\"" ]
}

@test "reinstalación idempotente que conserva la configuración" {
    mkdir -p "${XDG_CONFIG_HOME}/keshiki/resources"
    echo "anterior" >"${XDG_CONFIG_HOME}/keshiki/keshiki.cfg"

    run_user_install
    [ "$status" -eq 0 ]
    run_user_install
    [ "$status" -eq 0 ]

    grep -q "anterior" "${XDG_CONFIG_HOME}/keshiki/keshiki.cfg"
    # No debe haber directorios residuales de instalaciones repetidas.
    [ "$(find "$TEST_HOME/.local/share" -maxdepth 1 -name 'keshiki*' | wc -l)" -eq 1 ]
    [ -x "$TEST_HOME/.local/share/keshiki/keshiki.bash" ]
}

@test "instalación global en un prefijo aislado sin root" {
    prefix="$TEST_ROOT/prefijo local"
    cd "$TEST_ROOT" && run env KESHIKI_PREFIX="$prefix" "$REPO_ROOT/install.sh" --system
    [ "$status" -eq 0 ]

    [ -x "$prefix/share/keshiki/keshiki.bash" ]
    [ -L "$prefix/bin/keshiki" ]
    target="$(readlink -f "$prefix/bin/keshiki")"
    [ "$target" = "$prefix/share/keshiki/keshiki.bash" ]
    [ -f "$prefix/share/applications/keshiki.desktop" ]
}

@test "una dependencia obligatoria ausente aborta con código 2 y no instala" {
    # Stub dir con todas las dependencias menos mpv, más los binarios
    # externos que el propio instalador necesita para arrancar.
    mkdir -p "$TEST_ROOT/stubs-sin-mpv"
    for s in yad xwinwrap socat xdotool wmctrl xprop ffmpeg; do
        ln -s "$STUB_BIN/$s" "$TEST_ROOT/stubs-sin-mpv/$s"
    done
    for s in dirname readlink mktemp cp chmod grep sed rm mv ln mkdir cat id sleep; do
        ln -s "$(command -v "$s")" "$TEST_ROOT/stubs-sin-mpv/$s"
    done
    cd "$TEST_ROOT" && run env PATH="$TEST_ROOT/stubs-sin-mpv" "$REPO_ROOT/install.sh"
    [ "$status" -eq 2 ]
    [ ! -d "$TEST_HOME/.local/share/keshiki" ]
    [ ! -e "$TEST_HOME/.local/bin/keshiki" ]
}

@test "no sobrescribe un ejecutable ajeno en ~/.local/bin" {
    mkdir -p "$TEST_HOME/.local/bin"
    echo "programa ajeno" >"$TEST_HOME/.local/bin/keshiki"
    chmod +x "$TEST_HOME/.local/bin/keshiki"

    run_user_install
    [ "$status" -eq 3 ]
    [ "$(cat "$TEST_HOME/.local/bin/keshiki")" = "programa ajeno" ]
}

@test "un fallo de copia conserva la instalación anterior" {
    run_user_install
    [ "$status" -eq 0 ]
    app_dir="$TEST_HOME/.local/share/keshiki"
    mark_previous_version "marcador de la versión anterior"
    mkdir -p "$TEST_ROOT/failing"
    printf '#!/bin/bash\nexit 1\n' >"$TEST_ROOT/failing/cp"
    chmod +x "$TEST_ROOT/failing/cp"
    run env PATH="$TEST_ROOT/failing:$PATH" "$REPO_ROOT/install.sh"
    [ "$status" -ne 0 ]
    grep -q "marcador de la versión anterior" "$app_dir/keshiki.bash"
}

@test "un fallo de publicación restaura la instalación anterior" {
    run_user_install
    [ "$status" -eq 0 ]
    app_dir="$TEST_HOME/.local/share/keshiki"
    mark_previous_version "marcador de la versión anterior"
    mkdir -p "$TEST_ROOT/failing"
    cat >"$TEST_ROOT/failing/mv" <<'STUB'
#!/bin/bash
case "$*" in *'.keshiki-stage.'*) exit 1 ;; esac
exec /usr/bin/mv "$@"
STUB
    chmod +x "$TEST_ROOT/failing/mv"
    run env PATH="$TEST_ROOT/failing:$PATH" "$REPO_ROOT/install.sh"
    [ "$status" -ne 0 ]
    grep -q "marcador de la versión anterior" "$app_dir/keshiki.bash"
    [ -L "$TEST_HOME/.local/bin/keshiki" ]
}

@test "desinstalación de usuario elimina lo gestionado y conserva la configuración" {
    run_user_install
    [ "$status" -eq 0 ]

    mkdir -p "${XDG_CONFIG_HOME}/keshiki/resources/mi video"
    echo "config" >"${XDG_CONFIG_HOME}/keshiki/keshiki.cfg"
    echo "video de usuario" >"${XDG_CONFIG_HOME}/keshiki/resources/mi video/video.mp4"

    # Proceso ajeno que no debe ser tocado por la desinstalación.
    sleep 30 &
    foreign_pid=$!

    cd "$TEST_ROOT" && run "$REPO_ROOT/install.sh" --remove
    [ "$status" -eq 0 ]

    [ ! -e "$TEST_HOME/.local/share/keshiki" ]
    [ ! -e "$TEST_HOME/.local/bin/keshiki" ]
    [ ! -e "$TEST_HOME/.local/share/applications/keshiki.desktop" ]

    [ -f "${XDG_CONFIG_HOME}/keshiki/keshiki.cfg" ]
    [ -f "${XDG_CONFIG_HOME}/keshiki/resources/mi video/video.mp4" ]

    kill "$foreign_pid" 2>/dev/null
}

@test "la desinstalación respeta un enlace ajeno y es idempotente" {
    run_user_install
    [ "$status" -eq 0 ]

    foreign="$TEST_ROOT/otro-programa"
    echo "otro" >"$foreign"
    ln -sf "$foreign" "$TEST_HOME/.local/bin/keshiki"

    cd "$TEST_ROOT" && run "$REPO_ROOT/install.sh" --remove
    [ "$status" -eq 0 ]
    [ "$(readlink -f "$TEST_HOME/.local/bin/keshiki")" = "$foreign" ]

    run "$REPO_ROOT/install.sh" --remove
    [ "$status" -eq 0 ]
}

@test "advertencia sobre ~/.local/bin cuando no está en PATH" {
    cd "$TEST_ROOT" && run env PATH="/usr/bin:/bin" "$REPO_ROOT/install.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no está en tu PATH"* ]]
}

@test "el manifiesto manipulado no permite eliminar rutas ni instalaciones ajenas" {
    run_user_install
    [ "$status" -eq 0 ]
    foreign="$TEST_ROOT/foreign"
    mkdir "$foreign"
    echo keep >"$foreign/data"
    printf 'app_dir=%s\n' "$foreign" >>"$TEST_HOME/.local/share/keshiki/.keshiki-manifest"
    run "$REPO_ROOT/install.sh" --remove
    [ "$status" -ne 0 ]
    [ -f "$foreign/data" ]
    [ -f "$TEST_HOME/.local/share/keshiki/keshiki.bash" ]
}

@test "una desinstalación conserva archivos ajenos y puede repetirse" {
    run_user_install
    [ "$status" -eq 0 ]
    app_dir="$TEST_HOME/.local/share/keshiki"
    echo keep >"$app_dir/foreign"
    run "$REPO_ROOT/install.sh"
    [ "$status" -ne 0 ]
    run "$REPO_ROOT/install.sh" --remove
    [ "$status" -eq 0 ]
    [ -f "$app_dir/foreign" ]
    [ ! -e "$app_dir/keshiki.bash" ]
    run "$REPO_ROOT/install.sh" --remove
    [ "$status" -eq 0 ]
    [ -f "$app_dir/foreign" ]
}

@test "un directorio bin sustituido por enlace no se atraviesa" {
    run_user_install
    [ "$status" -eq 0 ]
    app_dir="$TEST_HOME/.local/share/keshiki"
    foreign="$TEST_ROOT/foreign"
    mkdir "$foreign"
    echo keep >"$foreign/mpv.bash"
    mv "$app_dir/bin" "$app_dir/old-bin"
    ln -s "$foreign" "$app_dir/bin"
    run "$REPO_ROOT/install.sh" --remove
    [ "$status" -ne 0 ]
    [ "$(cat "$foreign/mpv.bash")" = keep ]
}

@test "instalación y retirada globales aisladas no tocan la local" {
    run_user_install
    [ "$status" -eq 0 ]
    prefix="$TEST_ROOT/system prefix"
    run env KESHIKI_PREFIX="$prefix" "$REPO_ROOT/install.sh" --system
    [ "$status" -eq 0 ]
    run env KESHIKI_PREFIX="$prefix" "$REPO_ROOT/install.sh" --system --remove
    [ "$status" -eq 0 ]
    [ ! -e "$prefix/share/keshiki" ]
    [ -x "$TEST_HOME/.local/share/keshiki/keshiki.bash" ]
    run env KESHIKI_PREFIX="$prefix" "$REPO_ROOT/install.sh" --system --remove
    [ "$status" -eq 0 ]
}

@test "una instalación incompleta con manifiesto válido se puede retirar" {
    run_user_install
    [ "$status" -eq 0 ]
    app_dir="$TEST_HOME/.local/share/keshiki"
    rm -f "$app_dir/keshiki-add" "$TEST_HOME/.local/bin/keshiki"
    run "$REPO_ROOT/install.sh" --remove
    [ "$status" -eq 0 ]
    [ ! -e "$app_dir" ]
}

@test "la reinstalación actualiza un lanzador heredado" {
    run_user_install
    [ "$status" -eq 0 ]
    desktop="$TEST_HOME/.local/share/applications/keshiki.desktop"
    sed -i 's/^Exec=bash /Exec=/; s/^Icon=\(.*\)$/Icon="\1"/' "$desktop"
    run_user_install
    [ "$status" -eq 0 ]
    grep -q '^Exec=bash ' "$desktop"
    grep -qF "Icon=$TEST_HOME/.local/share/keshiki/keshiki.png" "$desktop"
    if command -v desktop-file-validate >/dev/null; then
        run desktop-file-validate "$desktop"
        [ "$status" -eq 0 ]
    fi
}

@test "un fallo después de sustituir el lanzador restaura la versión anterior" {
    run_user_install
    [ "$status" -eq 0 ]
    app_dir="$TEST_HOME/.local/share/keshiki"
    desktop="$TEST_HOME/.local/share/applications/keshiki.desktop"
    sed -i 's/^Exec=bash /Exec=/' "$desktop"
    cp "$desktop" "$TEST_ROOT/desktop-before"
    mark_previous_version 'old version marker'
    rm "$TEST_HOME/.local/bin/keshiki"
    mkdir -p "$TEST_ROOT/failing"
    cat >"$TEST_ROOT/failing/ln" <<'STUB'
#!/bin/bash
case "${@: -1}" in */.local/bin/keshiki) exit 1 ;; esac
exec /usr/bin/ln "$@"
STUB
    chmod +x "$TEST_ROOT/failing/ln"
    run env PATH="$TEST_ROOT/failing:$PATH" "$REPO_ROOT/install.sh"
    [ "$status" -ne 0 ]
    grep -q 'old version marker' "$app_dir/keshiki.bash"
    cmp "$desktop" "$TEST_ROOT/desktop-before"
}

@test "la desinstalación conserva archivos gestionados que fueron sustituidos" {
    run_user_install
    [ "$status" -eq 0 ]
    app_dir="$TEST_HOME/.local/share/keshiki"
    echo 'foreign replacement' >"$app_dir/keshiki-add"
    run "$REPO_ROOT/install.sh"
    [ "$status" -ne 0 ]
    run "$REPO_ROOT/install.sh" --remove
    [ "$status" -eq 0 ]
    [ "$(cat "$app_dir/keshiki-add")" = 'foreign replacement' ]
    [ ! -e "$app_dir/keshiki-start" ]
    run "$REPO_ROOT/install.sh" --remove
    [ "$status" -eq 0 ]
    [ "$(cat "$app_dir/keshiki-add")" = 'foreign replacement' ]
}

@test "no atraviesa un directorio XDG que sea un enlace simbólico" {
    foreign="$TEST_ROOT/foreign"
    mkdir "$foreign"
    echo keep >"$foreign/data"
    ln -s "$foreign" "$TEST_ROOT/data-link"
    run env XDG_DATA_HOME="$TEST_ROOT/data-link" "$REPO_ROOT/install.sh"
    [ "$status" -ne 0 ]
    [ "$(cat "$foreign/data")" = keep ]
    [ ! -e "$foreign/keshiki" ]
}

@test "el prefijo XDG admite barras invertidas y caracteres especiales" {
    export XDG_DATA_HOME="$TEST_ROOT/datos \\ % \"especial\""
    run_user_install
    [ "$status" -eq 0 ]
    [ -x "$XDG_DATA_HOME/keshiki/keshiki.bash" ]
    run_user_install
    [ "$status" -eq 0 ]
    run "$REPO_ROOT/install.sh" --remove
    [ "$status" -eq 0 ]
    [ ! -e "$XDG_DATA_HOME/keshiki" ]
}
