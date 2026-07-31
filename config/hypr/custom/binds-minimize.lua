-- Minimizar falso: mueve la ventana al workspace id+1000.
-- El dock la sigue mostrando como abierta y un clic ahi la regresa.
hl.bind("CTRL + SHIFT + D", function()
    local win = hl.get_active_window()
    if not win then return end

    local id = win.workspace.id
    if id < 1 or id > 1000 then return end

    hl.dispatch(hl.dsp.window.move({
        workspace = tostring(id + 1000),
        window = "address:" .. win.address,
        follow = false
    }))
end, { description = "Window: Minimizar (falso)" })

-- Restaura la ultima ventana minimizada del escritorio actual.
hl.bind("CTRL + SHIFT + ALT + D", function()
    local ws = hl.get_active_workspace()
    if not ws then return end

    local hidden = ws.id + 1000
    local candidate = nil

    for _, win in pairs(hl.get_windows()) do
        if win.workspace and win.workspace.id == hidden then
            candidate = win
        end
    end

    if not candidate then return end

    local address = "address:" .. candidate.address

    hl.dispatch(hl.dsp.window.move({
        workspace = tostring(ws.id),
        window = address,
        follow = false
    }))
    hl.dispatch(hl.dsp.focus({ window = address }))
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = address }))
end, { description = "Window: Restaurar minimizada" })

-- Mostrar escritorio: esconde todo en id+2000, o lo devuelve si ya esta escondido.
hl.bind("SUPER + D", function()
    local ws = hl.get_active_workspace()
    if not ws then return end

    local id = ws.id
    if id < 1 or id > 1000 then return end

    local stash = id + 2000
    local hidden = {}
    local visible = {}

    for _, win in pairs(hl.get_windows()) do
        if win.workspace then
            if win.workspace.id == stash then
                table.insert(hidden, win)
            elseif win.workspace.id == id then
                table.insert(visible, win)
            end
        end
    end

    if #hidden > 0 then
        for _, win in pairs(hidden) do
            hl.dispatch(hl.dsp.window.move({
                workspace = tostring(id),
                window = "address:" .. win.address,
                follow = false
            }))
        end
        return
    end

    for _, win in pairs(visible) do
        hl.dispatch(hl.dsp.window.move({
            workspace = tostring(stash),
            window = "address:" .. win.address,
            follow = false
        }))
    end
end, { description = "Workspace: Mostrar escritorio" })

-- Alt+Tab estilo Windows: cicla por orden de uso reciente.
-- La "foto" del orden se congela mientras ciclas y se descarta tras la pausa.
local alttab = { list = {}, index = 1, active = false, timer = nil }

local function alttab_snapshot()
    local wins = {}

    for _, win in pairs(hl.get_windows()) do
        -- Solo el workspace actual; el modulo cubre las minimizadas.
        local ws = hl.get_active_workspace()
        local curId = ws and ws.id or 1

        if win.workspace and win.workspace.id > 0
            and (win.workspace.id % 1000) == (curId % 1000) then
            table.insert(wins, win)
        end
    end

    table.sort(wins, function(a, b)
        return (a.focus_history_id or 99) < (b.focus_history_id or 99)
    end)

    return wins
end

local function alttab_step(delta, cycleAll)
    if not alttab.active or not cycleAll then
        alttab.list = alttab_snapshot()
        alttab.index = 1
        alttab.active = true
    end

    local total = #alttab.list
    if total < 2 then return end

    if cycleAll then
        alttab.index = ((alttab.index - 1 + delta) % total) + 1
    else
        -- Alterna solo entre las dos ultimas usadas.
        alttab.index = (alttab.index == 2) and 1 or 2
    end

    alttab.fastWindow = true
    alttab.fastStamp = (alttab.fastStamp or 0) + 1
    local fastMine = alttab.fastStamp

    hl.timer(function()
        if alttab.fastStamp == fastMine then
            alttab.fastWindow = false
        end
    end, { timeout = 250, type = "oneshot" })

    local win = alttab.list[alttab.index]

    if win then
        local address = "address:" .. win.address
        local minimizeBase = 1000
        local wsId = win.workspace.id

        -- Si esta minimizada, devuelvela a su escritorio original.
        if wsId > minimizeBase then
            hl.dispatch(hl.dsp.window.move({
                workspace = tostring(wsId % minimizeBase),
                window = address,
                follow = false
            }))
        end

        hl.dispatch(hl.dsp.focus({ window = address }))
        hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = address }))
    end

    alttab.stamp = (alttab.stamp or 0) + 1
    local mine = alttab.stamp

    hl.timer(function()
        -- Solo cierra el ciclo si no hubo otro Tab despues de este.
        if alttab.stamp == mine then
            alttab.active = false
        end
    end, { timeout = 600, type = "oneshot" })
end

hl.bind("ALT + Tab", function() alttab_step(1) end,
    { description = "Window: Alt-Tab (siguiente)" })

hl.bind("ALT + SHIFT + Tab", function() alttab_step(1, true) end,
    { description = "Window: Alt-Tab (anterior)" })
-- PRUEBA temporal: release de Alt
hl.bind("ALT_L", function()
    hl.notification.create({ text = "ALT soltado", timeout = 900 })
end, { release = true, description = "Prueba release" })
-- SUPER+Z: esconde todas menos la actual (ws id+3000). Otra vez las regresa detras.
hl.bind("SUPER + Z", function()
    local ws = hl.get_active_workspace()
    local active = hl.get_active_window()
    if not ws or not active then return end

    local id = ws.id
    if id < 1 or id > 1000 then return end

    local stash = id + 3000
    local hidden, others = {}, {}

    for _, win in pairs(hl.get_windows()) do
        if win.workspace then
            if win.workspace.id == stash then
                table.insert(hidden, win)
            elseif win.workspace.id == id and win.address ~= active.address then
                table.insert(others, win)
            end
        end
    end

    if #hidden > 0 then
        for _, win in pairs(hidden) do
            hl.dispatch(hl.dsp.window.move({
                workspace = tostring(id),
                window = "address:" .. win.address,
                follow = false
            }))
        end
        local addr = "address:" .. active.address
        hl.dispatch(hl.dsp.focus({ window = addr }))
        hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = addr }))
        return
    end

    for _, win in pairs(others) do
        hl.dispatch(hl.dsp.window.move({
            workspace = tostring(stash),
            window = "address:" .. win.address,
            follow = false
        }))
    end
end, { description = "Window: Aislar la actual" })

-- SUPER+B: alterna. Esconde la actual, y al siguiente toque recupera esa misma.
local btoggle = { stack = {}, lastWasMinimize = false }

hl.bind("SUPER + B", function()
    if #btoggle.stack > 0 then
        local entry = table.remove(btoggle.stack)
        local addr = "address:" .. entry.address

        hl.dispatch(hl.dsp.window.move({
            workspace = tostring(entry.ws),
            window = addr,
            follow = false
        }))
        hl.dispatch(hl.dsp.focus({ window = addr }))
        hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = addr }))

        btoggle.lastWasMinimize = false
        return
    end

    local win = hl.get_active_window()
    if not win then return end

    local id = win.workspace.id
    if id < 1 or id > 1000 then return end

    table.insert(btoggle.stack, { address = win.address, ws = id })
    hl.dispatch(hl.dsp.window.move({
        workspace = tostring(id + 1000),
        window = "address:" .. win.address,
        follow = false
    }))

    btoggle.lastWasMinimize = true
end, { description = "Window: Minimizar/restaurar alternado" })

