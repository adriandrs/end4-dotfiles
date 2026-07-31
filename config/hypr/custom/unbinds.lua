-- Desactiva binds de end4 que chocan con los propios.
-- Se hace aqui para no modificar hyprland/keybinds.lua (upstream).
hl.unbind("SUPER_L")            -- quickshell:workspaceNumber (lanzador al soltar Super)
hl.unbind("SUPER_R")
hl.unbind("SUPER + Tab")        -- overview; reemplazado por wstab_step
hl.unbind("SUPER + B")          -- sidebarLeft; reemplazado por esconder ventana
