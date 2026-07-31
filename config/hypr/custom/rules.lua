-- Permitir blur en todas las ventanas normales
hl.window_rule({
    match = {
        class = ".*"
    },
    no_blur = false
})



-- Blur en las capas del shell (usa el mismo decoration:blur global)
hl.layer_rule({ match = { namespace = "quickshell.*" }, blur = true })
