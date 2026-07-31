-- Redimensionar la ventana activa poco a poco.
hl.bind("SUPER + ALT + Left",  hl.dsp.window.resize({ x = -40, y = 0, relative = true }), { repeating = true })
hl.bind("SUPER + ALT + Right", hl.dsp.window.resize({ x = 40,  y = 0, relative = true }), { repeating = true })
hl.bind("SUPER + ALT + Up",    hl.dsp.window.resize({ x = 0, y = -40, relative = true }), { repeating = true })
hl.bind("SUPER + ALT + Down",  hl.dsp.window.resize({ x = 0, y = 40,  relative = true }), { repeating = true })


-- Lanzador en combinación explícita, sin release de Super suelto
hl.bind("SUPER + S", hl.dsp.global("quickshell:searchToggleRelease"),
    { description = "Lanzador" })


hl.bind("SUPER + I", function()
    hl.dispatch(hl.dsp.global("quickshell:searchToggleReleaseInterrupt"))
    hl.dispatch(hl.dsp.global("quickshell:settingsToggle"))
end, { description = "Config del shell actual" })

-- Envuelve un bind de Super para que quickshell no abra el lanzador al soltar.
local function superbind(key, action, opts)
    if type(action) == "function" then
        hl.bind(key, function()
            hl.dispatch(hl.dsp.global("quickshell:searchToggleReleaseInterrupt"))
            action()
        end, opts)
    else
        hl.bind(key, function()
            hl.dispatch(hl.dsp.global("quickshell:searchToggleReleaseInterrupt"))
            hl.dispatch(action)
        end, opts)
    end
end

-- Re-registra los binds de Super con el interrupt.



hl.bind("SUPER + Escape", hl.dsp.global("quickshell:overviewWorkspacesClose"),
    { description = "Cerrar overview" })

-- grid2x2: swap en vez de drag cuando hay 4 ventanas
local g2 = "~/.local/share/hypr-tools/grid2x2-drag.sh"
hl.bind("SUPER + mouse:272", hl.dsp.exec_cmd(g2 .. " press"))
hl.bind("SUPER + mouse:274", hl.dsp.exec_cmd(g2 .. " press"))
hl.bind("SUPER + mouse:272", hl.dsp.exec_cmd(g2 .. " release"), { release = true })
hl.bind("SUPER + mouse:274", hl.dsp.exec_cmd(g2 .. " release"), { release = true })
