-- Botones laterales para mover y redimensionar directamente.
--
-- mouse:276 (adelante):
--   mantener + mover el ratón = mover ventana
--
-- mouse:275 (atrás):
--   mantener + mover el ratón = redimensionar ventana
--
-- Al estar enlazados aquí, dejan de actuar como adelante/atrás.

hl.bind(
    "mouse:276",
    hl.dsp.window.drag(),
    {
        mouse = true,
        description = "Side mouse: Move window",
    }
)

hl.bind(
    "mouse:275",
    hl.dsp.window.resize(),
    {
        mouse = true,
        description = "Side mouse: Resize window",
    }
)
