#!/usr/bin/env bash
S=/tmp/grid2x2-drag
geo() { hyprctl -j clients | jq -c --argjson w "$(hyprctl -j activeworkspace | jq .id)" "[.[] | select(.workspace.id==\$w and .floating==false and .mapped==true)]"; }
under() {
  cx=$(hyprctl -j cursorpos | jq .x); cy=$(hyprctl -j cursorpos | jq .y)
  echo "$1" | jq -r --argjson x "$cx" --argjson y "$cy" "map(select(.at[0]<=\$x and \$x<=.at[0]+.size[0] and .at[1]<=\$y and \$y<=.at[1]+.size[1])) | .[0] // empty | [.address, (.at[0]+.size[0]/2), (.at[1]+.size[1]/2)] | @tsv"
}
case "$1" in
  press)
    d=$(geo)
    if [ -f "$HOME/.local/state/grid2x2drag" ] && [ "$(echo "$d" | jq length)" -eq 4 ]; then
      under "$d" > $S; [ -s $S ] || rm -f $S
    else
      rm -f $S
    fi ;;
  release)
    [ -f $S ] || exit 0
    read -r sa sx sy < $S; rm -f $S
    read -r ta tx ty < <(under "$(geo)")
    [ -n "$ta" ] && [ "$ta" != "$sa" ] || exit 0
    dx=$(( ${tx%.*} - ${sx%.*} )); dy=$(( ${ty%.*} - ${sy%.*} ))
    if [ "${dx#-}" -gt 20 ]; then
      if [ "$dx" -gt 0 ]; then h=r; else h=l; fi
      hyprctl dispatch "hl.dsp.window.swap({ direction = \"$h\", window = \"address:$sa\" })"
    fi
    if [ "${dy#-}" -gt 20 ]; then
      if [ "$dy" -gt 0 ]; then v=d; else v=u; fi
      hyprctl dispatch "hl.dsp.window.swap({ direction = \"$v\", window = \"address:$sa\" })"
    fi ;;
esac
