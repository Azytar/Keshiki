#!/bin/bash
# Realizado por: S.Konqi0139
#
# Eres libre de modificarlo a tu gusto, solo te pido
# nombrarme como autor del script
#
# La configuración de usuario se lee de una ruta variable y aporta
# variables como view, audio, opacity, below_desk o systemtray.

HERE="$(dirname "$(readlink -f "${0}")")"
export HERE DIRCONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/keshiki/" Color="color='#31E6F0'"
export CONFIG="${DIRCONFIG}keshiki.cfg" PATH="${HERE}/bin:${PATH}" ICON="${HERE}/keshiki.png" sc=${0##*/}

export script=${sc%.bash}

# shellcheck source=keshiki-session
source "$HERE/keshiki-session"
keshiki_register_component gui keshiki.bash || exit 0
cleanup_gui() {
    if [ -n "${YAD_MAIN_PID:-}" ] && [ -n "${yad_start:-}" ] &&
        [ "$(keshiki_start_time "$YAD_MAIN_PID")" = "$yad_start" ]; then
        kill -TERM "$YAD_MAIN_PID" 2>/dev/null || :
        wait "$YAD_MAIN_PID" 2>/dev/null || :
    fi
    keshiki_clear_own_component gui || :
}
trap cleanup_gui EXIT
trap 'exit 0' INT TERM HUP

view=(TRUE '')
systemtray=TRUE
if [ -f "${CONFIG}" ]; then
    # shellcheck disable=SC1090
    source "${CONFIG}" # configuración de usuario, ruta variable
else
    mkdir -p "${DIRCONFIG}desktops"
    echo -e "# configuration of keshiki\n\nview=(TRUE )\naudio=(FALSE --no-audio 100)\nsystemtray=TRUE\nbelow_desk=FALSE\nopacity=1" >"${CONFIG}"
    # shellcheck disable=SC1090
    source "${CONFIG}"
fi

restart() {
    "${HERE}/keshiki-cli" --close-gui || return 1
    "${HERE}/${sc}" &
}
export -f restart

if [[ $LANG == es* ]]; then
    Lan=("Añadir" "Quitar" "Detener" "Opacidad" "Opciones" "Gestor de Live Wallpapers")
else
    Lan=("Add" "Remove" "Stop" "Opacity" "Options" "Live Wallpaper Manager")
fi

keshiki --no-escape "${view[1]}" --center --always-print-result \
    --title="Keshiki" --width=970 --height=531 --text-align=center \
    --window-icon="$ICON" --buttons-layout=center --icons --monitor \
    --single-click --item-width=39 --read-dir="${DIRCONFIG}desktops" --borders=10 \
    --text="<span font='11' $Color><b><big>${Lan[5]}</big></b></span>" \
    --button="<span $Color>${Lan[0]}</span>!gtk-add:bash -c '\"\$HERE/keshiki-adding\"'" \
    --button="<span $Color>${Lan[1]}</span>!gtk-remove:bash -c '\"\$HERE/keshiki-remove\"'" \
    --button="<span $Color>${Lan[2]}</span>!gtk-media-stop:bash -c '\"\$HERE/keshiki-cli\" -f'" \
    --button="<span $Color>${Lan[3]}</span>!edit-opacity:bash -c '\"\$HERE/keshiki-options\" -o'" \
    --button="<span $Color>${Lan[4]}</span>!cm_options:bash -c '\"\$HERE/keshiki-options\"'" &
YAD_MAIN_PID=$!
yad_start=$(keshiki_start_time "$YAD_MAIN_PID") || yad_start=

if [ "$systemtray" = "TRUE" ]; then
    "${HERE}/keshiki-systray" &
else
    "${HERE}/keshiki-cli" --close-tray
fi

wait "$YAD_MAIN_PID" 2>/dev/null
