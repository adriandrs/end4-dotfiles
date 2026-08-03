#!/usr/bin/env bash
systemctl --user is-active --quiet grid2x2.service || exit 0
sleep 0.05
for _ in 1 2 3 4 5 6; do
  ws=$(hyprctl -j activeworkspace | jq .id)
  d=$(hyprctl -j clients | jq -c --argjson w "$ws" "[.[] | select(.workspace.id==\$w and .floating==false and .mapped==true)]")
  [ "$(echo "$d" | jq length)" -eq 4 ] || exit 0
  hh=$(echo "$d" | jq "map(.size[1]) | max"); lh=$(echo "$d" | jq "map(.size[1]) | min")
  hw=$(echo "$d" | jq "map(.size[0]) | max"); lw=$(echo "$d" | jq "map(.size[0]) | min")
  if (( hh > lh * 3 / 2 )); then
    bx=$(echo "$d" | jq "max_by(.size[1]) | .at[0]")
    sm=$(echo "$d" | jq -c "min_by(.size[0]*.size[1])")
    sx=$(echo "$sm" | jq ".at[0]"); ad=$(echo "$sm" | jq -r ".address")
    if (( bx < sx )); then dir=l; else dir=r; fi
  elif (( hw > lw * 3 / 2 )); then
    by=$(echo "$d" | jq "max_by(.size[0]) | .at[1]")
    sm=$(echo "$d" | jq -c "min_by(.size[0]*.size[1])")
    sy=$(echo "$sm" | jq ".at[1]"); ad=$(echo "$sm" | jq -r ".address")
    if (( by < sy )); then dir=u; else dir=d; fi
  else
    exit 0
  fi
  hyprctl dispatch "hl.dsp.window.move({ direction = \"$dir\", window = \"address:$ad\" })"
  sleep 0.03
done
