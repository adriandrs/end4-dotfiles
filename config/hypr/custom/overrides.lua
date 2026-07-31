-- Se carga despues de shellOverrides: aqui ganan estos valores.
-- Solo afecta VENTANAS. La transparencia del shell va en
-- ~/.config/illogical-impulse/config.json (appearance.transparency)
hl.config({
  general = {
    gaps_in = 2,
    gaps_out = 10,
  },
  decoration = {
    active_opacity = 0.85,
    inactive_opacity = 0.85,
    blur = { size = 8, passes = 5 },
  },
})
