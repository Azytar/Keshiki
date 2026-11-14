#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
lab=$(mktemp -d "$root/.audit-bug-006.XXXXXX")
trap 'rm -rf -- "$lab"' EXIT
mkdir -p -- "$lab/bin" "$lab/home/.config/keshiki/desktops" \
    "$lab/home/.config/keshiki/resources/Todo" \
    "$lab/home/.config/keshiki/resources/Another" \
    "$lab/home/.config/keshiki/resources/Keep"
if [[ ${1:-} == --baseline ]]; then
    git -C "$root" show 45a1e7e8793e97c0bd79f3953e9bda454ddae329:keshiki-remove > "$lab/keshiki-remove"
else
    cp -- "$root/keshiki-remove" "$lab/keshiki-remove"
fi
sed -e "s|/tmp/keshiki_final.lis|$lab/final.lis|" \
    -e "s|/tmp/keshiki_remove.lis|$lab/remove.lis|" \
    "$lab/keshiki-remove" > "$lab/keshiki-remove.local"
mv -- "$lab/keshiki-remove.local" "$lab/keshiki-remove"
cat > "$lab/bin/yad" <<'STUB'
#!/usr/bin/env bash
for index in ${AUDIT_SELECTIONS:-3}; do
    case "$index" in
        1) name=Another ;;
        2) name=Keep ;;
        3) name=Todo ;;
        *) exit 64 ;;
    esac
    printf 'FALSE|%s|gtk-video|%s\n' "$index" "$name"
done
STUB
chmod +x "$lab/bin/yad" "$lab/keshiki-remove"
: > "$lab/home/.config/keshiki/desktops/Todo.desktop"
: > "$lab/home/.config/keshiki/desktops/Another.desktop"
: > "$lab/home/.config/keshiki/desktops/Keep.desktop"
: > "$lab/home/.config/keshiki/resources/Another/image.jpg"
: > "$lab/home/.config/keshiki/resources/Todo/image.jpg"
: > "$lab/home/.config/keshiki/resources/Keep/image.jpg"
restart(){ :; }
export -f restart
HOME="$lab/home" DIRCONFIG="$lab/home/.config/keshiki/" \
    ICON="$root/keshiki.png" LANG=es_ES.UTF-8 AUDIT_SELECTIONS=3 PATH="$lab/bin:$PATH" \
    bash "$lab/keshiki-remove" > "$lab/remove.log" 2>&1

if [[ ! -f $lab/home/.config/keshiki/desktops/Keep.desktop ||
      ! -f $lab/home/.config/keshiki/resources/Keep/image.jpg ||
      ! -f $lab/home/.config/keshiki/desktops/Another.desktop ]]; then
    printf 'FAIL: selecting Todo also deleted the unrelated Keep entry\n' >&2
    exit 1
fi
if [[ -e $lab/home/.config/keshiki/desktops/Todo.desktop ]]; then
    printf 'FAIL: selected Todo entry was not removed\n' >&2
    exit 1
fi
multi_home="$lab/multi-home"
mkdir -p -- "$multi_home/.config/keshiki/desktops" \
    "$multi_home/.config/keshiki/resources/Another" \
    "$multi_home/.config/keshiki/resources/Keep" \
    "$multi_home/.config/keshiki/resources/Todo"
: > "$multi_home/.config/keshiki/desktops/Another.desktop"
: > "$multi_home/.config/keshiki/desktops/Keep.desktop"
: > "$multi_home/.config/keshiki/desktops/Todo.desktop"
: > "$multi_home/.config/keshiki/resources/Another/image.jpg"
: > "$multi_home/.config/keshiki/resources/Keep/image.jpg"
: > "$multi_home/.config/keshiki/resources/Todo/image.jpg"
HOME="$multi_home" DIRCONFIG="$multi_home/.config/keshiki/" \
    ICON="$root/keshiki.png" LANG=es_ES.UTF-8 AUDIT_SELECTIONS='1 3' \
    PATH="$lab/bin:$PATH" bash "$lab/keshiki-remove" \
    > "$lab/multi-remove.log" 2>&1
if [[ ! -f $multi_home/.config/keshiki/desktops/Keep.desktop ||
      -e $multi_home/.config/keshiki/desktops/Another.desktop ||
      -e $multi_home/.config/keshiki/desktops/Todo.desktop ]]; then
    printf 'FAIL: multi-selection did not remove only selected indices\n' >&2
    exit 1
fi
printf 'PASS: removing Todo preserved unrelated entries\n'
