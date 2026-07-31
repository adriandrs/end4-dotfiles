# end4-dotfiles

A customized [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) setup for
Hyprland 0.56 on CachyOS, extended with a Windows-style window management layer:
fake minimize, show desktop, MRU Alt+Tab, a rebuilt overview that lists live
windows, and an optional 2×2 grid layout.

Configuration only — no wallpapers, no themes, no personal data.

**Design rule:** nothing of mine lives inside upstream files. Every addition sits
in `custom/` or outside `~/.config/hypr` entirely, so end-4 can be updated without
merge conflicts. The one exception is documented under
[Modified upstream files](#modified-upstream-files).

---

## Table of contents

- [Features](#features)
- [Keybindings](#keybindings)
- [Installation](#installation)
- [Configuration guide](#configuration-guide)
- [Repository layout](#repository-layout)
- [Working on this setup](#working-on-this-setup)
- [Gotchas](#gotchas)
- [Known limitations](#known-limitations)

---

## Features

Upstream end-4 is a tiling-first setup. This fork keeps the Material You look and
adds the parts of a traditional desktop that Hyprland does not ship.

### Fake minimize

Hyprland has no concept of a minimized window. This setup emulates one by moving
windows to workspaces that no keybind can reach, using an offset that encodes
where the window came from:

| Offset | Meaning | Restored from |
| --- | --- | --- |
| `id + 1000` | single window minimized | dock click, `Ctrl+Shift+Alt+D`, `Super+B`, Alt+Tab |
| `id + 2000` | show desktop (all windows) | `Super+D` |
| `id + 3000` | isolate (all but the active one) | `Super+Z` |

A window minimized from workspace 3 lives on workspace 3003. Restoring is
`id % 1000`, which is why one restore path serves every offset. The state lives in
the compositor rather than in the shell, so it survives a quickshell restart.

The dock keeps showing minimized windows as open because the Wayland toplevel is
still mapped — only the workspace changed.

### MRU Alt+Tab

`Alt+Tab` cycles by Hyprland's own `focus_history_id` rather than by window order.
A snapshot is frozen on the first press so the list does not reshuffle underneath
you while cycling.

- Taps under 250 ms apart alternate between the two most recent windows, like Windows.
- Slower presses walk the full history.

Minimized windows are included and get restored to their original workspace when
selected.

### Rebuilt overview

`Super` opens the launcher with a grid of live window previews instead of the
workspace grid, filtered to the current workspace.

- `Tab` / `Shift+Tab` move a Material You selection ring across the previews.
- `Enter` focuses the selection and raises it to the top of the z-order.
- Closing the overview any other way also commits the pending selection, so
  `Super` → `Tab` `Tab` → `Super` is a complete switch without pressing Enter.
- Left click focuses and raises, right click closes.
- A pill button toggles back to the original end-4 workspace grid, which keeps
  drag-and-drop between workspaces.

Typing anything hands the keyboard back to the launcher, so app search is untouched.

### Persistent floating mode

`Super+H` converts every window on the current workspace to floating and restores
each one's last known geometry. The state persists across reboots in
`~/.cache/hypr-floating-mode/`.

The interesting part is how new windows are handled. A polling watcher can only
react *after* a window has been mapped and drawn, which produced a visible jump
from the tiling position to the saved position. Instead, entering the mode
registers `hl.window_rule` entries per window class, so new windows are born
floating at the right geometry — the rules are evaluated at map time, before the
first frame. The watcher stays on only to record positions as you move things and
to refresh the rules when they change.

Rules are registered with unique names per activation. Re-registering an existing
name silently stops it from applying on this Hyprland build, so nothing is ever
updated in place.

### 2×2 grid mode

Dwindle splits the *focused* window's node, so opening a fourth window usually
quarters one half instead of producing an even grid. On a wide monitor that means
windows that are needlessly small. Two independent switches fix it:

```bash
grid2x2 on | off | toggle          # force a 2×2 grid at four windows
grid2x2drag on | off | toggle      # dragging swaps instead of re-tiling
```

- `grid2x2` runs a systemd user service listening on Hyprland's event socket. When
  the fourth window opens it dispatches a move so the layout stays 2×2. Five or
  more windows behave exactly like stock dwindle.
- `grid2x2drag` replaces `Super`+drag with a positional swap while there are four
  windows, so dragging never produces thirds. Enabling it comments out end-4's
  native drag binds; disabling it restores them.

Both off is stock behaviour. Neither touches the layout config.

---

## Keybindings

Only additions and changes are listed. Everything else is upstream end-4; press
`Super+/` for the built-in cheatsheet.

### Window management

| Key | Action |
| --- | --- |
| `Alt+Tab` | cycle windows by recent use, restoring minimized ones |
| `Alt+Shift+Tab` | same, backwards |
| `Ctrl+Shift+D` | minimize the active window |
| `Ctrl+Shift+Alt+D` | restore the last minimized window on this workspace |
| `Super+B` | minimize the active window, or restore the last one you hid |
| `Super+D` | show desktop — hide everything, press again to bring it all back |
| `Super+Shift+D` | maximize |
| `Super+Z` | isolate the active window, press again to restore the rest |
| `Super+H` | toggle persistent floating mode for this workspace |
| `Super+Alt+←→↑↓` | resize the active window in small steps |

### Navigation

| Key | Action |
| --- | --- |
| `Super` | overview with live window previews |
| `Super+Space` | vicinae launcher |
| `Super+Tab` | switch between the two most recent workspaces |
| `Super+Shift+Tab` | cycle through workspaces that have windows |
| `Super+scroll` | previous / next workspace, clamped to 1–8 |
| `Super+Shift+drag` | drag left or right and release to change workspace |
| `Super+Alt+I` | enter / leave infinite-desktop submap |
| `Super+I` | open the active shell's config |
| `Middle mouse drag` | move a window without clicking through to the application |
| `Ctrl+Super+Alt+/` | open the `custom/` config directory |

---

## Installation

Requires an Arch-based system with Hyprland 0.56 or newer. Older releases use the
hyprlang configuration format and will not read the Lua config in this repository.

```bash
git clone https://github.com/adriandrs/end4-dotfiles.git ~/repos/end4-dotfiles
cd ~/repos/end4-dotfiles
./install.sh --packages
```

Then log out and select the Hyprland session.

### Options

```bash
./install.sh              # configuration only
./install.sh --packages   # also install everything from the package lists
./install.sh --dry-run    # print what would happen, write nothing
```

The installer backs up anything it is about to overwrite into
`~/.config/dotfiles-backup/<timestamp>/` before touching a single file.

### What the installer does not do

Some things are system-level and are deliberately left out:

- **Display manager.** Tested with GDM. Session selection per user lives in
  `/var/lib/AccountsService/users/<name>` and has to be set by hand.
- **User accounts and groups.**
- **The `swaync` and `plasma-kded6` masks** are applied, but only for the user
  running the script.

---

## Configuration guide

### Load order

Later wins. This is the actual order in `hyprland.lua`:

| # | File | Owner |
| --- | --- | --- |
| 1 | `hyprland/general.lua`, `rules.lua`, `keybinds.lua` | end-4 — **do not edit** |
| 2 | `custom/general.lua`, `rules.lua`, `keybinds.lua` | local |
| 3 | `hyprland/shellOverrides/main.lua` | quickshell **regenerates it** — do not edit |
| 4 | `custom/overrides.lua` | local — **always wins** |

**Key consequence:** anything that appears in `shellOverrides/main.lua` — gaps,
blur, opacity, border, rounding, layout, input, touchpad — is pointless to set in
`custom/general.lua`, because step 3 overwrites it. It belongs in
`custom/overrides.lua`.

> **Rule of thumb.** Appears in `shellOverrides/main.lua` → `overrides.lua`.
> Doesn't appear → `custom/general.lua`.

Verify which one won with `hyprctl getoption general:gaps_out`.

### Where to edit what

| To change | File |
| --- | --- |
| Gaps, blur, opacity, borders, rounding | `custom/overrides.lua` |
| Animations, dwindle, misc | `custom/general.lua` |
| Terminal and default apps | `custom/variables.lua` |
| Environment variables | `custom/env.lua` |
| Autostart | `custom/execs.lua` |
| Window rules | `custom/rules.lua` |
| Disable an end-4 bind | `custom/unbinds.lua` |
| Mouse binds | `custom/binds-mouse.lua` |
| Minimize, Alt+Tab, show desktop | `custom/binds-minimize.lua` |
| Workspaces, Super+Tab, infinite desktop | `custom/binds-workspace.lua` |
| Resize, launcher, grid2x2 | `custom/binds-window.lua` |
| Shell appearance (bar, dock, widgets) | `Config.qml` of the active shell |

Apply with `hyprctl reload`, then check `hyprctl configerrors`.

### The two shells

Both share the same `~/.config/hypr`. Only the quickshell config differs:

| Shell | Config |
| --- | --- |
| `ii` (main) | `~/.config/quickshell/ii/modules/common/Config.qml` |
| `end4-pC` (fork) | `~/.config/quickshell/end4-pC/modules/common/Config.qml` |

Switch with `qsw`; `Super+I` opens whichever is active.

`end4-pC` exposes `gapsIn`/`gapsOut` in its `Config.qml` while `ii` does not. On
the fork, editing them regenerates `shellOverrides/main.lua` and overrides
`custom/overrides.lua` — so on that shell, gaps belong in `Config.qml`.

### Disabling upstream binds

`custom/unbinds.lua` calls `hl.unbind()` on the end-4 binds that clash with local
ones — `SUPER_L`/`SUPER_R` (the launcher that fires on Super release),
`SUPER+Tab`, `SUPER+B`. It loads before the local binds and after upstream, so
upstream registers, this unregisters, then local binds take over. Upstream files
stay byte-identical.

---

## Repository layout

```
config/
  hypr/
    custom/               all local Hyprland config, split by topic
      keybinds.lua          entry point — requires only, no logic
      unbinds.lua           disables clashing end-4 binds
      binds-mouse.lua       middle-click drag and close, dual tiling/floating
      binds-minimize.lua    fake minimize, show desktop, MRU Alt+Tab
      binds-workspace.lua   workspace scroll and switching, infinite desktop
      binds-window.lua      fine resize, launcher, grid2x2
      general.lua           config quickshell does not override
      overrides.lua         config quickshell does override — loaded last
      rules.lua             window rules
      variables.lua         terminal and default apps
      env.lua               environment variables
      execs.lua             autostart
  quickshell/
    ii/                   main shell: bar, dock, overview, sidebars
    end4-pC/              alternate shell (fork)
  illogical-impulse/      shell settings, including per-app launch commands
  autostart/              XDG autostart entries
  systemd/user/           user units and masks, including grid2x2.service
  fastfetch/  cava/       terminal tools
  mimeapps.list           default applications
  kdedrc                  disables KDE modules that conflict with the shell
local/
  bin/                    grid2x2, grid2x2drag, gnome-control-center wrapper
  share/
    applications/         local .desktop overrides
    hypr-tools/           grid2x2 scripts, toggle-floating-mode.py, ws-cycle.sh
inputrc                   readline settings
packages-explicit.txt     every explicitly installed package
packages-aur.txt          AUR packages only
install.sh                restore this repository into a home directory
sync.sh                   copy a live home directory back into this repository
```

### Modified upstream files

The only upstream components intentionally patched. Re-check these when updating End-4:

- `quickshell/ii/modules/ii/overview/` — custom modes: current-workspace live window previews plus the original workspace grid, with a pill to switch.
- `quickshell/ii/modules/ii/bar/Workspaces.qml` — workspace-bar scrolling is clamped to workspaces 1–8.
- `quickshell/end4-pC/modules/ii/bar/Workspaces.qml` — applies the same workspace-scroll limit to the alternate shell.

At the moment, End-4 does not expose an override mechanism for replacing this
component, so these patches are maintained as intentional upstream modifications.

Everything else under `hypr/hyprland/` remains unmodified.

---

## Working on this setup

Edit files in `~/.config` as usual, then push the changes back:

```bash
cd ~/repos/end4-dotfiles
./sync.sh
git status --short
git add -A
git commit -m "..."
git push
```

`sync.sh` mirrors a fixed list of paths from `$HOME` into the repository,
excluding editor backups and build caches, and regenerates the two package lists.
It never deletes anything in `$HOME`.

### Reloading after a change

```bash
hyprctl reload                                   # Hyprland configuration
pkill -f "qs -c"                                 # quickshell — Hyprland restarts it
hyprctl configerrors                             # check for Lua syntax errors
```

A syntax error in any Lua file stops every keybind *after* the error from being
registered, so `hyprctl configerrors` is worth running after every edit.

### Tuning the dock

`config/quickshell/ii/modules/ii/dock/DockButton.qml` opens with a commented block
of variables for hover scale, animation timing, corner radius, and button height.
Change a number, restart quickshell, done.

---

## Gotchas

Things that cost real debugging time on Hyprland 0.56:

- **`hyprctl keyword` does not work** with the Lua parser. Use
  `hyprctl eval 'hl.config({ ... })'` instead.
- **Dispatchers are Lua tables**:
  `hyprctl dispatch 'hl.dsp.window.move({ direction = "l" })'`.
- **Window selectors need the `address:` prefix.**
- **Dwindle splits the focused window's node**, not the largest one. Split
  *direction* comes from the parent node's W/H ratio and
  `dwindle:split_width_multiplier`; which node gets split is purely focus.
- **`hl.dsp.window.drag()` only works as a bind handler.** Calling it through
  `hyprctl` returns `ok` and does nothing.
- **Rules registered at runtime via `eval` survive `hyprctl reload`.** Only a
  Hyprland restart clears them — worth knowing when a stray `float = true` rule
  makes every new window float.
- **`hyprland/shellOverrides/main.lua` is generated by quickshell.** Its header
  says so; edits are silently lost on the next shell start.
- **The quickshell settings panel is a layer surface**, not a window. It cannot be
  moved, floated, or targeted by window rules.

---

## Known limitations

**Application title-bar buttons.** A minimize button in a client-side decorated
window sends `xdg_toplevel.set_minimized`. Hyprland discards that request without
emitting anything on its IPC socket, so no script can hook it. Use the keybinds or
the dock instead. Maximize and close work normally.

**No hold-to-preview Alt+Tab.** Showing an overlay while Alt is held and
committing on release requires detecting the modifier release. Hyprland does not
report it for Alt even when the combination was consumed by a bind. `Super` plus
`Tab` covers the same ground with a persistent menu.

**Maximize gaps while floating.** `gaps_out` belongs to the tiling layout, so a
maximized floating window fills the whole work area. `Super+Shift+D` applies a
manual margin as a workaround; the application's own maximize button does not.

**One geometry per class in floating mode.** Window rules match on class, so with
three terminals open the rule uses the first one's geometry and the rest are
corrected by the watcher, which means they still jump.

**No live preview while grid-dragging.** With `grid2x2drag` enabled the window
does not follow the cursor during a drag; the swap happens on release. Making it
follow requires floating all four windows first so dwindle cannot rebalance, which
is implemented but not yet stable.

---

## Applications

The shell's per-app commands live in `config/illogical-impulse/config.json` under
`apps`. Upstream points these at KDE modules; this fork replaces them since Plasma
is not installed:

| Purpose | Application |
| --- | --- |
| Bluetooth | overskride |
| Network / users | GNOME Settings via a wrapper on `~/.local/bin` |
| Task manager | btop |
| PDF viewer | Papers |
| File manager | Nautilus |
| Launcher | vicinae |

GNOME Settings refuses to start outside a GNOME session, so
`local/bin/gnome-control-center` wraps it with `XDG_CURRENT_DESKTOP=GNOME`. The
variable is set for that one process only — setting it globally would break the
XDG portals, screen sharing, and screenshots.

---

## Credits

Built on [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland).
Shell framework: [quickshell](https://quickshell.org).
Compositor: [Hyprland](https://hypr.land).
