# Commands to run in interactive sessions can go here
if status is-interactive
    # No greeting
    set fish_greeting

    # Use starship
    function starship_transient_prompt_func
        starship module character
    end
    if test "$TERM" != "linux"
        starship init fish | source
        enable_transience
    end
    
    # Colors
#     if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
#         cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
#     end

    # Aliases
    # kitty doesn't clear properly so we need to do this weird printing
    alias clear "printf '\033[2J\033[3J\033[1;1H'"
    alias celar "printf '\033[2J\033[3J\033[1;1H'"
    alias claer "printf '\033[2J\033[3J\033[1;1H'"
    alias pamcan pacman
    alias q 'qs -c ii'
    if test "$TERM" != "linux"
        alias ls 'eza --icons=auto'
    end
    if test "$TERM" = "xterm-kitty"
        alias ssh 'kitten ssh'
    end
end
if status is-interactive; fastfetch; end

function qsw --description "Alterna entre ii y end4-pC"
    if pgrep -f "qs -c end4-pC" >/dev/null
        set target ii
    else
        set target end4-pC
    end
    killall qs 2>/dev/null
    qs -c $target >/dev/null 2>&1 &
    disown
    echo "→ $target"
end
