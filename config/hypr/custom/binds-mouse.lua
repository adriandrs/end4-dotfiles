hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/"), {description = "Edit user keybinds"} )
-- Modo dual: tiling <-> floating persistente
hl.bind(
    "SUPER + H",
    hl.dsp.exec_cmd(
        os.getenv("HOME") ..
        "/.local/share/hypr-tools/toggle-floating-mode.py"
    ),
    {
        description = "Workspace: Toggle persistent floating mode"
    }
)
-- Arrastrar una ventana con el botón central.
-- Un clic normal sigue llegando a la aplicación.
hl.bind(
    "CTRL + SHIFT + ALT + mouse:274",
    hl.dsp.window.drag(),
    {
        mouse = true,
        drag = true,
        auto_consuming = true,
        description = "Window: Drag with middle mouse button"
    }
)

-- Obtener estrictamente la ventana visible debajo del cursor.
local function middle_click_component(value, key)
   if type(value) ~= "table" then
      return 0
   end

   return tonumber(value[key]) or 0
end

local function window_under_cursor()
   local cursor = hl.get_cursor_pos()
   if not cursor then
      return nil
   end

   local cursor_x = tonumber(cursor.x) or 0
   local cursor_y = tonumber(cursor.y) or 0

   local target = nil
   local target_focus_rank = math.huge

   for _, win in ipairs(hl.get_windows()) do
      -- Ignora ventanas de otros escritorios, ocultas o no interactivas.
      if win.visible and win.accepts_input then
         local x = middle_click_component(win.at, "x")
         local y = middle_click_component(win.at, "y")
         local width = middle_click_component(win.size, "x")
         local height = middle_click_component(win.size, "y")

         local contains_cursor =
            width > 0 and
            height > 0 and
            cursor_x >= x and
            cursor_x < x + width and
            cursor_y >= y and
            cursor_y < y + height

         if contains_cursor then
            -- El valor menor corresponde a la ventana más reciente/superior.
            local focus_rank = tonumber(win.focus_history_id) or math.huge

            if focus_rank < 0 then
               focus_rank = math.huge
            end

            if not target or focus_rank < target_focus_rank then
               target = win
               target_focus_rank = focus_rank
            end
         end
      end
   end

   return target
end

-- Clic central corto: cerrar solo la ventana debajo del cursor.
hl.bind(
   "mouse:274",
   function()
      -- El dock y la barra son capas: Hyprland no las ve, asi que
      -- cerraria la ventana de abajo. Ceder el clic a quickshell.
      local function cursor_over_shell()
         local pos = hl.get_cursor_pos()
         if not pos then return false end

         local mon = hl.get_active_monitor()
         if not mon then return false end

         -- monitors devuelve px fisicos; el cursor esta en px logicos.
         local scale = mon.scale or 1
         local logicalHeight = 1121

         local barHeight = 63
         local dockHeight = 80

         if pos.y <= barHeight then return true end
         if pos.y >= (logicalHeight - dockHeight) then return true end

         return false
      end

      if cursor_over_shell() then
         return
      end

      local target = window_under_cursor()

      -- Escritorio vacío: no hacer nada.
      if not target then
         return
      end

      hl.dispatch(
         hl.dsp.window.close({
            window = target
         })
      )
   end,
   {
      mouse = true,
      click = true,
      non_consuming = true,
      description = "Window: Close strictly under cursor"
   }
)

