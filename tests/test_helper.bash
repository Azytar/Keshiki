# Utilidades compartidas por las pruebas de Bats.
# shellcheck shell=bash

REPO_ROOT="$(cd "$(dirname "$(readlink -f "${BATS_TEST_FILENAME}")")/.." && pwd)"
export REPO_ROOT
TEST_ROOT=""
TEST_HOME=""
RUNTIME=""
STUB_BIN=""
XWINWRAP_LOG=""

# Registra la invocación de un comando simulado en "$TEST_ROOT". Los
# stubs son autónomos: no pueden llamar a funciones de este proceso.

# Crea los comandos simulados que Keshiki necesita. Ninguna prueba
# ejecuta herramientas reales de vídeo ni requiere una sesión X11.
make_stubs() {
    local stubs="$STUB_BIN"
    mkdir -p "$stubs/bin"

    cat >"$stubs/yad" <<EOF
#!/bin/bash
printf '%s\0' "\$@" >> "$TEST_ROOT/yad.log"
if printf '%s\n' "\$*" | grep -q -- "--list --checklist"; then
    [ -f "$TEST_ROOT/yad-selection.txt" ] && cat "$TEST_ROOT/yad-selection.txt"
fi
exit 0
EOF

    cat >"$stubs/bin/mpv.bash" <<EOF
#!/bin/bash
printf '%s\0' "\$@" >> "$TEST_ROOT/mpv.log"
if [ -n "\${KESHIKI_MPV_STUB_SLEEP:-}" ]; then
    sleep "\$KESHIKI_MPV_STUB_SLEEP"
fi
exit 0
EOF

    cat >"$stubs/xwinwrap" <<EOF
#!/bin/bash
[ "\${1:-}" != -h ] || exit 0
printf '%s\0' "\$@" >> "$TEST_ROOT/xwinwrap.log"
exit 0
EOF

    printf '#!/bin/bash\nexit 0\n' >"$stubs/xdotool"

    cat >"$stubs/ffmpegthumbnailer" <<EOF
#!/bin/bash
# Genera la miniatura solo cuando se le pide comportamiento válido.
printf '%s\0' "\$@" >> "$TEST_ROOT/ffmpegthumbnailer.log"
if [ "\${KESHIKI_THUMB_FAIL:-}" = 1 ]; then
    exit 1
fi
out=""
prev=""
for a in "\$@"; do
    if [ "\$prev" = "-o" ]; then out="\$a"; fi
    prev="\$a"
done
[ -n "\$out" ] && printf 'fake-jpeg-data' > "\$out"
exit 0
EOF

    cat >"$stubs/ffprobe" <<EOF
#!/bin/bash
printf '%s\0' "\$@" >> "$TEST_ROOT/ffprobe.log"
printf '640|360|30/1|10.000000\n'
EOF

    cat >"$stubs/convert" <<EOF
#!/bin/bash
printf '%s\0' "\$@" >> "$TEST_ROOT/convert.log"
dst="\${@: -1}"
printf 'fake-resized' > "\$dst"
exit 0
EOF

    printf '#!/bin/bash\nexit 0\n' >"$stubs/xdotool"
    printf '#!/bin/bash\nexit 0\n' >"$stubs/wmctrl"
    printf '#!/bin/bash\nexit 0\n' >"$stubs/xprop"

    chmod +x "$stubs/yad" "$stubs/ffmpegthumbnailer" \
        "$stubs/ffprobe" "$stubs/convert" "$stubs/xdotool" "$stubs/wmctrl" \
        "$stubs/xprop" "$stubs/bin/mpv.bash" "$stubs/xwinwrap"
}

setup_env() {
    # Un HOME con espacios ejercita el manejo de rutas no triviales.
    TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/keshiki-test.XXXXXX")"
    TEST_HOME="$TEST_ROOT/home de prueba"
    RUNTIME="$TEST_ROOT/runtime"
    STUB_BIN="$TEST_ROOT/stubs"
    XWINWRAP_LOG="$TEST_ROOT/xwinwrap.log"
    mkdir -p "$TEST_HOME/.config" "$TEST_HOME/.local/share" "$RUNTIME" "$STUB_BIN"
    chmod 700 "$RUNTIME"
    export HOME="$TEST_HOME"
    export XDG_CONFIG_HOME="$TEST_HOME/.config"
    export XDG_DATA_HOME="$TEST_HOME/.local/share"
    export XDG_RUNTIME_DIR="$RUNTIME"
    unset XDG_CACHE_HOME
    make_stubs
    export PATH="$STUB_BIN:$PATH"
    : >"$XWINWRAP_LOG"
}

teardown_env() {
    if [ -n "${TEST_ROOT:-}" ] && [ -d "$TEST_ROOT" ]; then
        rm -rf "$TEST_ROOT"
    fi
}

write_config() {
    mkdir -p "${XDG_CONFIG_HOME}/keshiki"
    cat >"${XDG_CONFIG_HOME}/keshiki/keshiki.cfg" <<'EOF'
view=(TRUE --generic)
audio=(TRUE --no-audio 100)
systemtray=FALSE
below_desk=FALSE
opacity=1
EOF
}

# Espera a que un archivo de registro reciba contenido.
wait_for_log() {
    local log="$1" i
    for ((i = 0; i < 100; i++)); do
        [ -s "$log" ] && return 0
        sleep 0.05
    done
    return 1
}
