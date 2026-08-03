#!/usr/bin/env bash
# uso: ws-cycle.sh +1 | -1
cur=$(hyprctl activeworkspace -j | jq -r '.id')
next=$(( cur + $1 ))
(( next > 10 )) && next=1
(( next < 1  )) && next=10
hyprctl dispatch workspace "$next"
