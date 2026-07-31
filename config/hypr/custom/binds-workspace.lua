-- Scroll entre workspaces, limitado a 1-8.
local function wsStep(delta)
    local ws = hl.get_active_workspace()
    if not ws then return end
    local target = ws.id + delta
    if target < 1 or target > 8 then return end
    hl.dispatch(hl.dsp.focus({ workspace = tostring(target) }))
end


hl.bind("SUPER + mouse_down", function() wsStep(1) end)
hl.bind("SUPER + mouse_up", function() wsStep(-1) end)

-- CTRL+SUPER+flechas: workspaces limitados al mismo rango que el scroll.
hl.unbind("CTRL + SUPER + Left")
hl.unbind("CTRL + SUPER + Right")

hl.bind("CTRL + SUPER + Left", function()
    wsStep(-1)
end, { description = "Workspace: Focus left, bounded" })

hl.bind("CTRL + SUPER + Right", function()
    wsStep(1)
end, { description = "Workspace: Focus right, bounded" })

hl.bind("ALT + Space", hl.dsp.exec_cmd("vicinae toggle"),
    { description = "Lanzador vicinae" })

-- SUPER+SHIFT+arrastre con boton izquierdo: cambia de workspace al soltar.
local wsdrag = { startX = nil, threshold = 150 }

hl.bind("SUPER + SHIFT + mouse:272", function()
    local pos = hl.get_cursor_pos()
    wsdrag.startX = pos and pos.x or nil
end, { mouse = true })

hl.bind("SUPER + SHIFT + mouse:272", function()
    if not wsdrag.startX then return end

    local pos = hl.get_cursor_pos()
    if not pos then return end

    local dx = pos.x - wsdrag.startX
    wsdrag.startX = nil

    if math.abs(dx) < wsdrag.threshold then return end

    local ws = hl.get_active_workspace()
    if not ws then return end

    local target = ws.id + (dx < 0 and 1 or -1)
    if target < 1 or target > 8 then return end

    hl.dispatch(hl.dsp.focus({ workspace = tostring(target) }))
end, { mouse = true, release = true })


-- Super+Tab: alterna entre los dos ultimos workspaces usados.
-- Super+Shift+Tab: cicla por todos los que tienen ventanas.
-- Interrumpe la apertura del lanzador al soltar Super.
local wstab = { list = {}, index = 1, active = false, last = nil, stamp = 0 }

local function ws_with_windows()
    local seen, out = {}, {}

    for _, win in pairs(hl.get_windows()) do
        local id = win.workspace and win.workspace.id
        if id and id > 0 and id < 1000 and not seen[id] then
            seen[id] = true
            table.insert(out, id)
        end
    end

    table.sort(out)
    return out
end

local function wstab_step(cycleAll)
    -- Evita que quickshell abra el lanzador al soltar Super.
    hl.dispatch(hl.dsp.global("quickshell:searchToggleReleaseInterrupt"))

    local current = hl.get_active_workspace()
    if not current then return end

    if not cycleAll then
        -- Ignora la repeticion de tecla: dos disparos volverian al origen.
        if wstab.debounce then return end
        wstab.debounce = true
        hl.timer(function() wstab.debounce = false end,
            { timeout = 300, type = "oneshot" })

        local target = wstab.last

        if not target or target == current.id then
            -- Sin historial: usa el siguiente workspace con ventanas.
            local list = ws_with_windows()
            for _, id in ipairs(list) do
                if id ~= current.id then target = id break end
            end
        end

        if not target or target == current.id then return end

        wstab.last = current.id
        hl.dispatch(hl.dsp.focus({ workspace = tostring(target) }))
        return
    end

    -- Ignora el doble disparo por repeticion de tecla.
    if wstab.debounceAll then return end
    wstab.debounceAll = true
    hl.timer(function() wstab.debounceAll = false end,
        { timeout = 300, type = "oneshot" })

    -- Orden ascendente por id, recalculado en cada pulsacion.
    local list = ws_with_windows()
    local total = #list
    if total < 2 then return end

    local pos = 1
    for i, id in ipairs(list) do
        if id == current.id then pos = i end
    end

    local nextPos = (pos % total) + 1
    wstab.last = current.id

    hl.dispatch(hl.dsp.focus({ workspace = tostring(list[nextPos]) }))
end

hl.bind("SUPER + Tab", function() wstab_step(false) end,
    { description = "Workspace: alternar los dos ultimos" })

hl.bind("SUPER + SHIFT + Tab", function() wstab_step(true) end,
    { description = "Workspace: ciclar por todos" })

-- Registra el workspace anterior en cada cambio.
hl.on("workspace.active", function(ev)
    local prev = wstab.current
    wstab.current = ev and ev.workspace and ev.workspace.id
    if prev and prev ~= wstab.current then wstab.last = prev end
end)

-- ─────────── MODO INFINITE DESKTOP ───────────
-- SUPER + ALT + I entra y sale. Escape tambien sale.
local infiniteScripts = os.getenv("HOME") .. "/scripts"

hl.define_submap("infinite", function()
    hl.bind("Left",  hl.dsp.exec_cmd("python3 " .. infiniteScripts .. "/navigate_windows.py left"))
    hl.bind("Right", hl.dsp.exec_cmd("python3 " .. infiniteScripts .. "/navigate_windows.py right"))
    hl.bind("Up",    hl.dsp.exec_cmd("python3 " .. infiniteScripts .. "/navigate_windows.py up"))
    hl.bind("Down",  hl.dsp.exec_cmd("python3 " .. infiniteScripts .. "/navigate_windows.py down"))

    hl.bind("SHIFT + Left",  hl.dsp.exec_cmd("python3 " .. infiniteScripts .. "/move_window.py left"),  { repeating = true })
    hl.bind("SHIFT + Right", hl.dsp.exec_cmd("python3 " .. infiniteScripts .. "/move_window.py right"), { repeating = true })
    hl.bind("SHIFT + Up",    hl.dsp.exec_cmd("python3 " .. infiniteScripts .. "/move_window.py up"),    { repeating = true })
    hl.bind("SHIFT + Down",  hl.dsp.exec_cmd("python3 " .. infiniteScripts .. "/move_window.py down"),  { repeating = true })

    hl.bind("CTRL + Left",  hl.dsp.exec_cmd("python3 " .. infiniteScripts .. "/resize_window.py left"),  { repeating = true })
    hl.bind("CTRL + Right", hl.dsp.exec_cmd("python3 " .. infiniteScripts .. "/resize_window.py right"), { repeating = true })
    hl.bind("CTRL + Up",    hl.dsp.exec_cmd("python3 " .. infiniteScripts .. "/resize_window.py up"),    { repeating = true })
    hl.bind("CTRL + Down",  hl.dsp.exec_cmd("python3 " .. infiniteScripts .. "/resize_window.py down"),  { repeating = true })

    hl.bind("ALT + Left",  hl.dsp.exec_cmd("python3 " .. infiniteScripts .. "/move_window_tiled.py left"))
    hl.bind("ALT + Right", hl.dsp.exec_cmd("python3 " .. infiniteScripts .. "/move_window_tiled.py right"))
    hl.bind("ALT + Up",    hl.dsp.exec_cmd("python3 " .. infiniteScripts .. "/move_window_tiled.py up"))
    hl.bind("ALT + Down",  hl.dsp.exec_cmd("python3 " .. infiniteScripts .. "/move_window_tiled.py down"))

    -- Los submaps desactivan los binds globales; hay que repetirlos aqui.
    hl.bind("SUPER + mouse:272", hl.dsp.window.drag(),
        { mouse = true, description = "Window: Move (infinite)" })
    hl.bind("SUPER + mouse:273", hl.dsp.window.resize(),
        { mouse = true, description = "Window: Resize (infinite)" })

    hl.bind("D", hl.dsp.exec_cmd("python3 " .. infiniteScripts .. "/floating_tile_toggle.py"))

    hl.bind("Escape", function()
        hl.dispatch(hl.dsp.exec_cmd("pkill -f infinite_desktop_core.py"))
        hl.dispatch(hl.dsp.exec_cmd("notify-send 'Infinite desktop' 'Modo desactivado' -a 'Hyprland'"))
        hl.dispatch(hl.dsp.submap("reset"))
    end)
end)

hl.bind("SUPER + ALT + I", function()
    if hl.get_current_submap() == "infinite" then
        hl.dispatch(hl.dsp.exec_cmd("pkill -f infinite_desktop_core.py"))
        hl.dispatch(hl.dsp.exec_cmd("notify-send 'Infinite desktop' 'Modo desactivado' -a 'Hyprland'"))
        hl.dispatch(hl.dsp.submap("reset"))
    else
        hl.dispatch(hl.dsp.exec_cmd(infiniteScripts .. "/infinite-toggle.sh"))
        hl.dispatch(hl.dsp.submap("infinite"))
    end
end, { submap_universal = true, description = "Toggle infinite desktop mode" })

