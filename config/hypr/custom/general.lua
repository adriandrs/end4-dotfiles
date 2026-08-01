hl.config({
    general = {
        -- Separación entre ventanas
        gaps_in = 2,

        -- Espacio entre ventanas y bordes de la pantalla
        gaps_out = 20,

        -- Separación visual entre workspaces
        gaps_workspaces = 50,

        -- Grosor del borde
        border_size = 1,

        -- Permite redimensionar arrastrando el borde
        resize_on_border = true,

        -- Colores del borde
        col = {
            -- active_border = "rgba(0DB7D488)",
            -- inactive_border = "rgba(31313622)"
        },

        -- Ajuste magnético al mover ventanas
        snap = {
            enabled = true,
            window_gap = 8,
            monitor_gap = 12,
            respect_gaps = true
        }
    },

    decoration = {
        -- Redondeado de ventanas
        rounding = 22,

        -- 2 = circular; valores mayores dan apariencia squircle
        rounding_power = 2.5,

        -- Transparencia global
        active_opacity = 0.85,
        inactive_opacity = 0.85,
 	fullscreen_opacity = 0.85,

        blur = {
            enabled = true,

            -- Necesario para que se vea blur con ventanas transparentes
            ignore_opacity = true,

            -- false suele funcionar mejor para ventanas normales
            xray = false,

            new_optimizations = true,

            -- Intensidad principal del blur
            size = 15,
            passes = 3,

            -- Apariencia del vidrio
            brightness = 1,
            contrast = 1.0,
            noise = 0.02,
            vibrancy = 0.8,
            vibrancy_darkness = 1,

            -- Blur en menús y popups
            popups = true,
            popups_ignorealpha = 0.6,

            -- Blur en métodos de entrada
            input_methods = true,
            input_methods_ignorealpha = 0.8
        },

        shadow = {
            enabled = false,

            -- Tamaño de la sombra
            range = 20,

            -- Desplazamiento horizontal y vertical
            offset = {0, 4},

            -- Intensidad del renderizado
            render_power = 4,

            -- Últimos dos dígitos = opacidad hexadecimal
            color = "rgba(00000055)"
        },

        -- Oscurecer ventanas inactivas
        dim_inactive = false,
        dim_strength = 0.08,

        -- Oscurecimiento de workspaces especiales
        dim_special = 0.20
    },

    animations = {
        enabled = true
    },

    dwindle = {
        -- Mantiene la dirección de las divisiones
        preserve_split = true,

        -- Decide automáticamente la dirección del split
        smart_split = false,

        -- Redimensionado inteligente
        smart_resizing = false
    },

    misc = {
        -- Animación al redimensionar manualmente
        animate_manual_resizes = false,

        -- Animación al arrastrar ventanas
        animate_mouse_windowdragging = false,

        -- VRR; 0 desactivado, 1 automático, 2 siempre
        vrr = 0
    },

    cursor = {
        no_warps = true
    },
    binds = {
        drag_threshold = 8
    }
})
hl.config({ dwindle = { force_split = 2 } })
