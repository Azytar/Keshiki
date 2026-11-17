#!/bin/bash
# Realizado por: S.Konqi0139
# Mantenido por: Azytar y colaboradores
#
# Eres libre de modificarlo a tu gusto, solo te pido
# nombrarme como autor del script
#
# Instalador de Keshiki.
#
# Modos de instalación (excluyentes entre sí):
#   usuario (predeterminado)  ~/.local, sin privilegios
#   sistema (--system o root) /usr/local, requiere privilegios
#
# El script nunca invoca sudo por sí mismo y nunca instala dependencias:
# si falta alguna herramienta obligatoria, informa cómo resolverlo y aborta.

set -u

CReset='\e[m'
BRed='\e[1;31m' BGreen='\e[1;32m' BYellow='\e[1;33m' BCyan='\e[1;36m'
PGreen='\e[5;01m\e[1;32m' PYellow='\e[5;01m\e[1;33m'

# Herramientas sin las cuales Keshiki no puede funcionar.
required_deps=(yad mpv xwinwrap socat xdotool wmctrl xprop ffmpeg flock setsid sha256sum)
# Herramientas que añaden funciones (YouTube, miniaturas rápidas, redimensionado
# óptimo, metadatos, motor JS para yt-dlp) pero tienen alternativa o degradación.
optional_deps=(yt-dlp ffmpegthumbnailer convert magick ffprobe deno node qjs)

program_files=(
    keshiki.bash keshiki-start keshiki-cli keshiki-add keshiki-adding
    keshiki-remove keshiki-options keshiki-systray keshiki-playlist keshiki-session
    keshiki-about keshiki.png about-keshiki.png
)

die() {
    local code="$1"
    shift
    printf '\n%bError:%b %s\n' "$BRed" "$CReset" "$*" >&2
    exit "$code"
}

warn() {
    printf '%bAviso:%b %s\n' "$BYellow" "$CReset" "$*"
}

ok() {
    printf '%b[*]%b %b%s%b%b\n' "$PYellow" "$CReset" "$BCyan" "$1" "$BGreen" " Instalado.$CReset"
}

missing() {
    printf '%b[*]%b %b%s%b %s\n' "$PYellow" "$CReset" "$BCyan" "$1" "$BRed" "$2"
}

usage() {
    cat <<EOF
Uso: ./install.sh [OPCIONES]

OPCIONES
    (predeterminado)  instalar en ~/.local sin privilegios de root
    --system          instalar en /usr/local (requiere privilegios de root)
    --remove          desinstalar la instalación del modo seleccionado
    -h, --help        mostrar esta ayuda

El instalador nunca ejecuta sudo por su cuenta: usa «sudo ./install.sh»
cuando quieras la instalación de sistema.
EOF
}

# ---------------------------------------------------------------- modo

mode=user
want_remove=0

for arg in "$@"; do
    case "$arg" in
        --system)
            mode=system
            ;;
        --user)
            mode=user
            ;;
        --remove)
            want_remove=1
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            die 1 "Opción desconocida: $arg"
            ;;
    esac
done

if [ "$(id -u)" -eq 0 ]; then
    mode=system
elif [ "$mode" = "system" ] && [ -z "${KESHIKI_PREFIX:-}" ]; then
    # KESHIKI_PREFIX permite redirigir la instalación de sistema a un
    # prefijo de pruebas (lo usan las pruebas de regresión); solo exige
    # privilegios cuando el destino real lo necesita.
    die 1 "La instalación de sistema requiere privilegios. Ejecuta: sudo ./install.sh"
fi

HERE="$(dirname "$(readlink -f "${0}")")"

if [ "$mode" = "user" ]; then
    data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
    app_dir="$data_home/keshiki"
    bin_dir="$HOME/.local/bin"
    desktop_dir="$data_home/applications"
    bin_link="$bin_dir/keshiki"
    desktop_file="$desktop_dir/keshiki.desktop"
else
    prefix="${KESHIKI_PREFIX:-/usr/local}"
    app_dir="$prefix/share/keshiki"
    bin_dir="$prefix/bin"
    desktop_dir="$prefix/share/applications"
    bin_link="$bin_dir/keshiki"
    desktop_file="$desktop_dir/keshiki.desktop"
fi

# ------------------------------------------------------------ utilidades

# Escapa un valor para el campo Exec de un archivo .desktop según la
# especificación de Desktop Entry (no siguen las reglas de comillas de Bash).
# SC1003: el patrón \\ compara deliberadamente una sola barra invertida.
# shellcheck disable=SC1003
desktop_exec_arg() {
    local input="$1" output="" char i
    for ((i = 0; i < ${#input}; i++)); do
        char=${input:i:1}
        case "$char" in
            \\) output+='\\\\' ;;
            '"') output+='\\"' ;;
            '`') output+='\\`' ;;
            '$') output+='\\$' ;;
            %) output+='%%' ;;
            *) output+="$char" ;;
        esac
    done
    printf '"%s"' "$output"
}

check_dependencies() {
    local missing_required=0 prog

    echo -e "\n${BCyan}Revisando dependencias de Keshiki...${CReset}\n"
    for prog in "${required_deps[@]}"; do
        if command -v "$prog" >/dev/null 2>&1; then
            ok "$prog"
        else
            missing "$prog" "No está instalado (Requerido)."
            missing_required=1
        fi
    done

    echo ""
    for prog in "${optional_deps[@]}"; do
        if command -v "$prog" >/dev/null 2>&1; then
            ok "$prog (Opcional)"
        else
            printf '%b[+]%b %b%s%b %s\n' "$PYellow" "$CReset" "$BCyan" "$prog" "$BYellow" \
                "No instalado (Opcional: YouTube, miniaturas rápidas o redimensionado)."
        fi
    done

    if [ "$missing_required" -eq 1 ]; then
        printf '\n%bFaltan dependencias requeridas.%b\n' "$BRed" "$CReset"
        echo "Keshiki no funcionará sin ellas. Instálalas con el gestor de paquetes"
        echo "de tu distribución (por ejemplo: pacman, apt, dnf) y vuelve a intentar."
        echo "Requeridas: ${required_deps[*]}"
        exit 2
    fi
}

# Comprueba que la fuente esté completa ANTES de tocar la instalación actual.
check_source() {
    local f
    for f in "${program_files[@]}"; do
        [ -f "$HERE/$f" ] || die 1 "Falta el archivo del programa: $HERE/$f"
    done
    command -v yad >/dev/null 2>&1 || die 2 "yad es obligatorio para preparar los lanzadores internos."
}

# Los ejecutables internos de Keshiki son yad con otro argv0 y un
# envoltorio de mpv que permite identificar la sesión de reproducción.
build_internal_bin() {
    local stage="$1" dest

    mkdir "$stage/bin" || return 1
    dest="$(command -v yad)"
    ln -s "$dest" "$stage/bin/keshiki" || return 1
    ln -s "$dest" "$stage/bin/yadsystray" || return 1

    cat >"$stage/bin/mpv.bash" <<'EOF' || return 1
#!/bin/bash
HERE="$(dirname "$(dirname "$(readlink -f "$0")")")"
source "$HERE/keshiki-session"
if [ -n "${KESHIKI_SESSION_DIR:-}" ]; then
    start=$(keshiki_start_time "$$") || exit 1
    printf '%s %s\n' "$$" "$start" >"$KESHIKI_SESSION_DIR/mpv.pid" || exit 1
fi
exec mpv "$@"
EOF
    chmod +x "$stage/bin/mpv.bash" || return 1
    return 0
}

# Valida el árbol preparado antes de sustituir la instalación previa.
verify_stage() {
    local stage="$1" f
    [ -d "$stage/bin" ] || return 1
    [ -x "$stage/bin/mpv.bash" ] || return 1
    [ -L "$stage/bin/keshiki" ] || return 1
    for f in "${program_files[@]}"; do
        [ -e "$stage/$f" ] || return 1
    done
    chmod +x "$stage"/keshiki.bash "$stage"/keshiki-* || return 1
    [ -x "$stage/keshiki.bash" ] || return 1
    [ -x "$stage/keshiki-start" ] || return 1
    return 0
}

build_desktop_entry() {
    local exec_arg icon_arg
    exec_arg="$(desktop_exec_arg "$app_dir/keshiki.bash")"
    icon_arg=${app_dir//\\/\\\\}
    icon_arg=${icon_arg//$'\n'/\\n}
    icon_arg=${icon_arg//$'\r'/\\r}
    icon_arg=${icon_arg//$'\t'/\\t}
    icon_arg="$icon_arg/keshiki.png"
    cat <<EOF
[Desktop Entry]
Version=1.3
Name=Keshiki
Comment=Gestor de Live Wallpapers para compositores basados en X11
Exec=bash $exec_arg
Icon=$icon_arg
Type=Application
Categories=AudioVideo;Video;GTK;Utility;
Terminal=false
StartupNotify=false
StartupWMClass=Keshiki
Keywords=wallpaper;utility;live;background;
EOF
}

# Protección de archivos ajenos: solo sustituimos bin/desktop si apuntan a
# una instalación de Keshiki reconocible; cualquier otra cosa se respeta.
link_is_ours() {
    local path="$1" target
    [ -L "$path" ] || return 1
    target="$(readlink "$path")"
    if [ "$target" = "$app_dir/keshiki.bash" ]; then
        return 0
    fi
    # Enlaces anteriores pueden estar resueltos a la ruta canónica.
    target="$(readlink -f "$path" 2>/dev/null)" || return 1
    [ "$target" = "$app_dir/keshiki.bash" ]
}

desktop_is_ours() {
    [ -f "$1" ] || return 1
    grep -qxF "Exec=bash $(desktop_exec_arg "$app_dir/keshiki.bash")" "$1" 2>/dev/null ||
        grep -qxF "Exec=$(desktop_exec_arg "$app_dir/keshiki.bash")" "$1" 2>/dev/null
}

manifest_header() {
    printf '# Keshiki installation manifest v2 (mode: %s)\napp_dir=%s\nbin_link=%s\ndesktop_file=%s\n' \
        "$mode" "$app_dir" "$bin_link" "$desktop_file"
}

manifest_write() {
    local dir=$1 f digest target
    manifest_header || return 1
    for f in "${program_files[@]}" bin/mpv.bash; do
        read -r digest _ < <(sha256sum <"$dir/$f") || return 1
        printf 'file %s %s\n' "$f" "$digest" || return 1
    done
    for f in bin/keshiki bin/yadsystray; do
        target=$(readlink -- "$dir/$f") || return 1
        read -r digest _ < <(printf '%s' "$target" | sha256sum) || return 1
        printf 'link %s %s\n' "$f" "$digest" || return 1
    done
}

declare -A managed_hash=() managed_type=()
manifest_load() {
    local dir=$1 line kind path digest extra i=4 expected expected_type
    local -a lines expected_paths=("${program_files[@]}" bin/mpv.bash bin/keshiki bin/yadsystray)
    [ -f "$dir/.keshiki-manifest" ] && [ ! -L "$dir/.keshiki-manifest" ] || return 1
    mapfile -t lines <"$dir/.keshiki-manifest" || return 1
    [ "${#lines[@]}" -eq "$((4 + ${#expected_paths[@]}))" ] || return 1
    printf '%s\n' "${lines[@]:0:4}" | cmp -s - <(manifest_header) || return 1
    managed_hash=() managed_type=()
    for expected in "${expected_paths[@]}"; do
        line=${lines[i]}
        read -r kind path digest extra <<<"$line"
        expected_type='file'
        case $expected in bin/keshiki | bin/yadsystray) expected_type='link' ;; esac
        [[ $kind = "$expected_type" && $path = "$expected" && $digest =~ ^[0-9a-f]{64}$ && -z $extra ]] || return 1
        managed_hash[$expected]=$digest
        managed_type[$expected]=$kind
        ((i += 1))
    done
}

valid_manifest() {
    manifest_load "$app_dir"
}

managed_matches() {
    local dir=$1 path=$2 digest target
    case ${managed_type[$path]:-} in
        file)
            [ -f "$dir/$path" ] && [ ! -L "$dir/$path" ] || return 1
            read -r digest _ < <(sha256sum <"$dir/$path") || return 1
            ;;
        link)
            [ -L "$dir/$path" ] || return 1
            target=$(readlink -- "$dir/$path") || return 1
            read -r digest _ < <(printf '%s' "$target" | sha256sum) || return 1
            ;;
        *) return 1 ;;
    esac
    [ "$digest" = "${managed_hash[$path]}" ]
}

# Never follow a symlink in an installation path, including an existing parent.
no_symlink_components() {
    local path=$1 part current=''
    local -a parts
    [[ $path = /* && $path != *$'\n'* && $path != *$'\r'* ]] || return 1
    IFS=/ read -r -a parts <<<"$path"
    for part in "${parts[@]}"; do
        [ -n "$part" ] || continue
        [ "$part" != . ] && [ "$part" != .. ] || return 1
        current="$current/$part"
        [ ! -L "$current" ] || return 1
    done
}

check_paths() {
    if ! no_symlink_components "$app_dir" || ! no_symlink_components "$bin_dir" ||
        ! no_symlink_components "$desktop_dir"; then
        die 3 'Una ruta de instalación contiene un enlace simbólico o no es absoluta.'
    fi
}

# An update may replace only the files this installer manages.
managed_tree_only() {
    local dir=$1 path name known f
    [ -d "$dir" ] && [ ! -L "$dir" ] || return 1
    shopt -s nullglob dotglob
    for path in "$dir"/*; do
        name=${path##*/}
        if [ "$name" = bin ]; then
            [ -d "$path" ] && [ ! -L "$path" ] || {
                shopt -u nullglob dotglob
                return 1
            }
            for f in "$path"/*; do
                case ${f##*/} in
                    keshiki | yadsystray | mpv.bash) managed_matches "$dir" "bin/${f##*/}" || {
                        shopt -u nullglob dotglob
                        return 1
                    } ;;
                    *)
                        shopt -u nullglob dotglob
                        return 1
                        ;;
                esac
            done
        else
            known=0
            [ "$name" = .keshiki-manifest ] && known=1
            for f in "${program_files[@]}"; do [ "$name" != "$f" ] || known=1; done
            if [ "$known" -ne 1 ] || [ -d "$path" ] ||
                { [ "$name" != .keshiki-manifest ] && ! managed_matches "$dir" "$name"; }; then
                shopt -u nullglob dotglob
                return 1
            fi
        fi
    done
    shopt -u nullglob dotglob
}

remove_managed_tree() {
    local dir=$1 f path remaining
    [ -d "$dir" ] && [ ! -L "$dir" ] && manifest_load "$dir" || return 1
    if [ -e "$dir/bin" ] || [ -L "$dir/bin" ]; then
        [ -d "$dir/bin" ] && [ ! -L "$dir/bin" ] || return 1
    fi
    for f in "${program_files[@]}" bin/mpv.bash bin/keshiki bin/yadsystray; do
        path="$dir/$f"
        if [ -e "$path" ] || [ -L "$path" ]; then
            if managed_matches "$dir" "$f"; then
                rm -f -- "$path" || return 1
            else
                warn "Se conserva el archivo modificado $path."
            fi
        fi
    done
    [ ! -d "$dir/bin" ] || rmdir -- "$dir/bin" 2>/dev/null || :
    remaining=$(find "$dir" -mindepth 1 -maxdepth 1 ! -name .keshiki-manifest -print -quit) || return 1
    [ -n "$remaining" ] || rm -f -- "$dir/.keshiki-manifest" || return 1
    rmdir -- "$dir" 2>/dev/null || :
}

do_install() {
    local stage f app_parent backup='' desktop_tmp='' desktop_backup='' keep_desktop_backup=0 made_desktop=0 made_link=0
    check_paths
    check_source
    check_dependencies
    if [ -e "$app_dir" ]; then
        if ! valid_manifest || ! managed_tree_only "$app_dir"; then
            die 3 "El destino $app_dir contiene archivos ajenos o no tiene un manifiesto válido."
        fi
    fi
    if { [ -e "$bin_link" ] || [ -L "$bin_link" ]; } && ! link_is_ours "$bin_link"; then
        die 3 "Ya existe «$bin_link» y no pertenece a esta instalación."
    fi
    if [ -L "$desktop_file" ] || { [ -e "$desktop_file" ] && ! desktop_is_ours "$desktop_file"; }; then
        die 3 "Ya existe «$desktop_file» y no pertenece a esta instalación."
    fi
    app_parent=$(dirname "$app_dir")
    mkdir -p -- "$app_parent" "$bin_dir" "$desktop_dir" || die 1 'No se pudieron crear los directorios.'
    stage=$(mktemp -d "$app_parent/.keshiki-stage.XXXXXXXX") || die 1 'No se pudo preparar la instalación.'
    trap 'rm -rf -- "$stage"; [ -z "$desktop_tmp" ] || rm -f -- "$desktop_tmp"; [ "$keep_desktop_backup" -ne 0 ] || [ -z "$desktop_backup" ] || rm -f -- "$desktop_backup"' EXIT
    trap 'exit 1' INT TERM HUP
    for f in "${program_files[@]}"; do
        cp -- "$HERE/$f" "$stage/$f" || die 1 "Fallo al copiar $f."
    done
    if ! build_internal_bin "$stage" || ! verify_stage "$stage"; then
        die 1 'No se pudo validar la instalación preparada.'
    fi
    manifest_write "$stage" >"$stage/.keshiki-manifest" || die 1 'No se pudo preparar el manifiesto.'
    desktop_tmp=$(mktemp "$desktop_dir/.keshiki-desktop.XXXXXXXX") || die 1 'No se pudo preparar el acceso de menú.'
    if ! build_desktop_entry >"$desktop_tmp" || ! chmod 644 "$desktop_tmp"; then
        die 1 'No se pudo preparar el acceso de menú.'
    fi
    if [ -e "$desktop_file" ]; then
        if cmp -s "$desktop_tmp" "$desktop_file"; then
            rm -f -- "$desktop_tmp"
            desktop_tmp=''
        else
            desktop_backup=$(mktemp "$desktop_dir/.keshiki-desktop-old.XXXXXXXX") || die 1 'No se pudo guardar el acceso anterior.'
            cp -p -- "$desktop_file" "$desktop_backup" || die 1 'No se pudo guardar el acceso anterior.'
        fi
    fi
    # Complete the short publication/rollback sequence before acting on signals.
    trap '' INT TERM HUP
    if [ -d "$app_dir" ]; then
        backup=$(mktemp -d "$app_parent/.keshiki-old.XXXXXXXX") || die 1 'No se pudo reservar la copia anterior.'
        if ! rmdir -- "$backup" || ! mv -T -- "$app_dir" "$backup"; then
            die 1 'No se pudo conservar la instalación anterior.'
        fi
    fi
    if ! mv -T -- "$stage" "$app_dir"; then
        [ -z "$backup" ] || mv -T -- "$backup" "$app_dir" || warn "Restaura manualmente $backup en $app_dir."
        [ -z "$desktop_backup" ] || rm -f -- "$desktop_backup"
        die 1 'No se pudo publicar la instalación.'
    fi
    if [ -n "$desktop_tmp" ]; then
        if [ -n "$desktop_backup" ]; then
            if mv -T -- "$desktop_tmp" "$desktop_file"; then made_desktop=1; else f=failed; fi
        else
            if ln -- "$desktop_tmp" "$desktop_file"; then made_desktop=1; else f=failed; fi
        fi
    fi
    if [ ! -L "$bin_link" ]; then
        if ln -s -- "$app_dir/keshiki.bash" "$bin_link"; then made_link=1; else f=failed; fi
    fi
    if [ "${f:-}" = failed ] || [ ! -x "$app_dir/keshiki.bash" ] || ! valid_manifest ||
        ! link_is_ours "$bin_link" || ! desktop_is_ours "$desktop_file"; then
        if [ "$made_desktop" -ne 0 ]; then
            if [ -n "$desktop_backup" ]; then
                if ! mv -T -- "$desktop_backup" "$desktop_file"; then
                    keep_desktop_backup=1
                    warn "Restaura manualmente $desktop_backup en $desktop_file."
                fi
            else
                rm -f -- "$desktop_file"
            fi
        elif [ -n "$desktop_backup" ]; then
            rm -f -- "$desktop_backup"
        fi
        [ "$made_link" -eq 0 ] || rm -f -- "$bin_link"
        remove_managed_tree "$app_dir" || warn "No se pudo retirar $app_dir."
        [ -z "$backup" ] || mv -T -- "$backup" "$app_dir" || warn "Restaura manualmente $backup en $app_dir."
        die 1 'No se pudo publicar la instalación; se intentó restaurar la versión anterior.'
    fi
    if [ -n "$backup" ]; then
        remove_managed_tree "$backup" || warn "Se conservó la copia anterior en $backup."
    fi
    [ -z "$desktop_backup" ] || rm -f -- "$desktop_backup"
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$desktop_dir" >/dev/null 2>&1 || :
    fi
    [ -z "$desktop_tmp" ] || rm -f -- "$desktop_tmp"
    trap - EXIT INT TERM HUP
    echo -e "\n${PGreen}Instalación Completa${CReset}"
    if [ "$mode" = user ] && ! printf '%s' "$PATH" | tr ':' '\n' | grep -qxF "$bin_dir"; then
        printf '%bNota:%b %s no está en tu PATH.\n' "$BYellow" "$CReset" "$bin_dir"
    fi
}

do_remove() {
    check_paths
    if [ -e "$app_dir" ]; then
        if [ ! -d "$app_dir" ] || ! valid_manifest; then
            die 3 "No hay un manifiesto válido en $app_dir; se conserva."
        fi
        # Do not traverse a substituted bin directory or managed directory names.
        [ ! -L "$app_dir/bin" ] || die 3 'El directorio bin es un enlace simbólico.'
        local f
        for f in "${program_files[@]}"; do
            [ ! -d "$app_dir/$f" ] || die 3 "Se conserva el directorio inesperado $app_dir/$f."
        done
        if ! (
            installer_dir=$HERE
            HERE=$app_dir
            # shellcheck source=keshiki-session
            source "$installer_dir/keshiki-session"
            keshiki_lock || exit 1
            keshiki_stop && keshiki_stop_component gui keshiki.bash &&
                keshiki_stop_component tray keshiki-systray
            status=$?
            keshiki_unlock
            exit "$status"
        ); then
            die 1 'No se pudo detener la sesión propia.'
        fi
        remove_managed_tree "$app_dir" || die 1 'No se pudieron retirar los archivos gestionados.'
        [ ! -e "$app_dir" ] || warn "Se conservaron archivos ajenos en $app_dir."
    fi
    if [ -L "$bin_link" ] && link_is_ours "$bin_link"; then
        rm -f -- "$bin_link" || die 1 "No se pudo eliminar $bin_link."
    fi
    if [ ! -L "$desktop_file" ] && [ -f "$desktop_file" ] && desktop_is_ours "$desktop_file"; then
        rm -f -- "$desktop_file" || die 1 "No se pudo eliminar $desktop_file."
    fi
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$desktop_dir" >/dev/null 2>&1 || :
    fi
    echo -e "\n${PGreen}Archivos gestionados de Keshiki eliminados.${CReset}"
    echo 'Se conservan la configuración y los wallpapers personales.'
}

# ------------------------------------------------------------------- main

if [ "$want_remove" -eq 1 ]; then
    do_remove
else
    do_install
fi

exit 0
