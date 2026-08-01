-- Permitir blur en todas las ventanas normales
hl.window_rule({
    match = {
        class = ".*"
    },
    no_blur = false
})



-- Blur en las capas del shell (usa el mismo decoration:blur global)
hl.layer_rule({ match = { namespace = "quickshell.*" }, blur = true })
hl.layer_rule({ match = { namespace = "quickshell:barMenu" }, blur = true })
hl.layer_rule({ match = { namespace = "quickshell:barMenu" }, ignore_alpha = 0 })
hl.layer_rule({ match = { namespace = "quickshell:popup" }, blur = true })
hl.layer_rule({ match = { namespace = "quickshell:mediaControls" }, ignore_alpha = 0 })
hl.layer_rule({ match = { namespace = "quickshell:mediaControls" }, blur = true })
hl.layer_rule({ match = { namespace = "quickshell:popup" }, ignore_alpha = 0.4 })
