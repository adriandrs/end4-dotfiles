#!/usr/bin/env bash
[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] || HYPRLAND_INSTANCE_SIGNATURE=$(ls -t "$XDG_RUNTIME_DIR/hypr" | head -1)
sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
geo() { hyprctl -j clients | jq -c --argjson w "$(hyprctl -j activeworkspace | jq .id)" "[.[] | select(.workspace.id==\$w and .floating==false and .mapped==true)]"; }
socat -U - UNIX-CONNECT:"$sock" | while read -r line; do
  [[ "$line" == openwindow* ]] || continue
  prev=""; d=""
  for _ in $(seq 40); do
    d=$(geo)
    [ "$(echo "$d" | jq length)" -eq 4 ] && [ "$d" = "$prev" ] && break
    prev="$d"; sleep 0.01
  done
  [ "$(echo "$d" | jq length)" -eq 4 ] || continue
  hi=$(echo "$d" | jq "map(.size[1]) | max"); lo=$(echo "$d" | jq "map(.size[1]) | min")
  (( hi > lo * 3 / 2 )) || continue
  tx=$(echo "$d" | jq "max_by(.size[1]) | .at[0]")
  ax=$(hyprctl -j activewindow | jq ".at[0]")
  if (( tx < ax )); then dir=l; else dir=r; fi
  hyprctl dispatch "hl.dsp.window.move({ direction = \"$dir\" })"
done
