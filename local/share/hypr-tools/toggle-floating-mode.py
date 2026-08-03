#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


CACHE_DIR = Path.home() / ".cache" / "hypr-floating-mode"
LAYOUTS_FILE = CACHE_DIR / "layouts.json"
RUNTIME_FILE = CACHE_DIR / "runtime.json"
WATCHER_PID_FILE = CACHE_DIR / "watcher.pid"

POLL_INTERVAL = 0.6

# Desplazamiento en px al abrir otra ventana encima de una existente.
CASCADE_OFFSET = 32
CASCADE_TOLERANCE = 8


def run_command(args: list[str], check: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        text=True,
        capture_output=True,
        check=check,
    )


def hypr_json(command: str) -> Any:
    result = run_command(["hyprctl", command, "-j"])

    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"hyprctl {command} failed")

    return json.loads(result.stdout)


def dispatch(expression: str) -> bool:
    result = run_command(["hyprctl", "dispatch", expression])
    return result.returncode == 0


def notify(title: str, message: str) -> None:
    run_command(["notify-send", title, message])


def load_json(path: Path, default: Any) -> Any:
    try:
        with path.open("r", encoding="utf-8") as file:
            return json.load(file)
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return default


def save_json(path: Path, data: Any) -> None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)

    temporary = path.with_suffix(path.suffix + ".tmp")

    with temporary.open("w", encoding="utf-8") as file:
        json.dump(data, file, indent=2, ensure_ascii=False)

    temporary.replace(path)


def instance_signature() -> str:
    return os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "unknown")


def normalized_runtime() -> dict[str, Any]:
    runtime = load_json(
        RUNTIME_FILE,
        {
            "signature": instance_signature(),
            "modes": {},
        },
    )

    current_signature = instance_signature()

    # Después de reiniciar Hyprland, el estado floating activo anterior
    # se considera terminado, pero las geometrías guardadas permanecen.
    if runtime.get("signature") != current_signature:
        runtime = {
            "signature": current_signature,
            "modes": {},
        }
        save_json(RUNTIME_FILE, runtime)

    runtime.setdefault("modes", {})
    return runtime


def active_workspace_id() -> str:
    workspace = hypr_json("activeworkspace")
    return str(workspace["id"])


def clients() -> list[dict[str, Any]]:
    data = hypr_json("clients")
    return [client for client in data if client.get("mapped", True)]


def workspace_clients(workspace_id: str) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []

    for client in clients():
        workspace = client.get("workspace") or {}

        if str(workspace.get("id")) == workspace_id:
            result.append(client)

    return result


def client_base_identity(client: dict[str, Any]) -> str:
    """
    Identidad persistente aproximada.

    Usa initialClass y class porque suelen sobrevivir reinicios mejor
    que la dirección de memoria y el título dinámico.
    """
    initial_class = str(client.get("initialClass") or "")
    current_class = str(client.get("class") or "")
    return f"{initial_class}|{current_class}"


def clients_with_keys(
    current_clients: list[dict[str, Any]],
) -> list[tuple[str, dict[str, Any]]]:
    """
    Si existen varias ventanas de la misma aplicación, agrega un índice
    estable dentro de la sesión.
    """
    grouped: dict[str, list[dict[str, Any]]] = {}

    for client in current_clients:
        grouped.setdefault(client_base_identity(client), []).append(client)

    result: list[tuple[str, dict[str, Any]]] = []

    for base_identity, group in grouped.items():
        group.sort(key=lambda item: str(item.get("address", "")))

        for index, client in enumerate(group):
            key = f"{base_identity}#{index}"
            result.append((key, client))

    return result


def selector(address: str) -> str:
    return f"address:{address}"


def set_floating(address: str, enabled: bool) -> None:
    action = "enable" if enabled else "disable"
    window = json.dumps(selector(address))

    dispatch(
        "hl.dsp.window.float({ "
        f'action = "{action}", '
        f"window = {window} "
        "})"
    )


def resize_window(address: str, width: int, height: int) -> None:
    window = json.dumps(selector(address))

    dispatch(
        "hl.dsp.window.resize({ "
        f"x = {int(width)}, "
        f"y = {int(height)}, "
        "relative = false, "
        f"window = {window} "
        "})"
    )


def move_window(address: str, x: int, y: int) -> None:
    window = json.dumps(selector(address))

    dispatch(
        "hl.dsp.window.move({ "
        f"x = {int(x)}, "
        f"y = {int(y)}, "
        "relative = false, "
        f"window = {window} "
        "})"
    )


def eval_lua(expression: str) -> bool:
    result = run_command(["hyprctl", "eval", expression])
    output = (result.stdout or "").strip()
    return result.returncode == 0 and not output.lower().startswith("error")


def lua_string(value: str) -> str:
    return json.dumps(value)


def class_from_key(key: str) -> str:
    base = key.rsplit("#", 1)[0]
    initial_class, _, current_class = base.partition("|")
    return current_class or initial_class


def register_rules(workspace_id: str) -> list[str]:
    """
    Registra reglas de ventana para que lo nuevo nazca ya flotando
    y en su sitio, en vez de que el watcher lo corrija después.
    """
    layouts = load_json(LAYOUTS_FILE, {})
    workspace_layout = layouts.get(workspace_id, {})
    stamp = int(time.time())
    names: list[str] = []

    catch_all = f"floatmode-{workspace_id}-{stamp}-all"

    if eval_lua(
        "hl.window_rule({ "
        f"name = {lua_string(catch_all)}, "
        f"match = {{ workspace = {lua_string(workspace_id)} }}, "
        "float = true "
        "})"
    ):
        names.append(catch_all)

    seen: set[str] = set()

    for index, (key, saved) in enumerate(sorted(workspace_layout.items())):
        if not key.endswith("#0"):
            continue

        window_class = class_from_key(key)

        if not window_class or window_class in seen:
            continue

        seen.add(window_class)

        name = f"floatmode-{workspace_id}-{stamp}-{index}"
        move_value = f"{saved['x']} {saved['y']}"
        size_value = f"{saved['width']} {saved['height']}"

        if eval_lua(
            "hl.window_rule({ "
            f"name = {lua_string(name)}, "
            f"match = {{ class = {lua_string(window_class)}, "
            f"workspace = {lua_string(workspace_id)} }}, "
            "float = true, "
            f"move = {lua_string(move_value)}, "
            f"size = {lua_string(size_value)} "
            "})"
        ):
            names.append(name)

    return names


def disable_rules(names: list[str]) -> None:
    for name in names:
        eval_lua(
            "hl.window_rule({ "
            f"name = {lua_string(name)}, "
            "enabled = false "
            "})"
        )


def covered_classes(workspace_id: str) -> list[str]:
    layouts = load_json(LAYOUTS_FILE, {})
    workspace_layout = layouts.get(workspace_id, {})
    result: list[str] = []

    for key in sorted(workspace_layout):
        if not key.endswith("#0"):
            continue

        window_class = class_from_key(key)

        if window_class and window_class not in result:
            result.append(window_class)

    return result


def geometry_signature(workspace_id: str) -> str:
    layouts = load_json(LAYOUTS_FILE, {})
    workspace_layout = layouts.get(workspace_id, {})
    relevant = {
        key: value
        for key, value in workspace_layout.items()
        if key.endswith("#0")
    }
    return json.dumps(relevant, sort_keys=True)


def refresh_rules(workspace_id: str, runtime: dict[str, Any]) -> None:
    """
    Vuelve a registrar las reglas cuando cambian las geometrías guardadas.
    Sin esto, las reglas quedan congeladas en el momento de activar el modo.
    """
    mode_data = runtime.get("modes", {}).get(workspace_id)

    if mode_data is None:
        return

    signature = geometry_signature(workspace_id)

    if mode_data.get("signature") == signature:
        return

    disable_rules(mode_data.get("rules", []))

    mode_data["rules"] = register_rules(workspace_id)
    mode_data["classes"] = covered_classes(workspace_id)
    mode_data["signature"] = signature

    save_json(RUNTIME_FILE, runtime)


def float_and_place(address: str, saved: dict[str, int] | None) -> None:
    """
    Flotar, redimensionar y mover en una sola evaluacion, para que
    Hyprland no alcance a renderizar la posicion intermedia.
    """
    window = json.dumps(selector(address))

    calls = [
        "hl.dispatch(hl.dsp.window.float({ action = \"enable\", "
        f"window = {window} }}))"
    ]

    if saved is not None:
        calls.append(
            "hl.dispatch(hl.dsp.window.resize({ "
            f"x = {int(saved['width'])}, y = {int(saved['height'])}, "
            f"relative = false, window = {window} }}))"
        )
        calls.append(
            "hl.dispatch(hl.dsp.window.move({ "
            f"x = {int(saved['x'])}, y = {int(saved['y'])}, "
            f"relative = false, window = {window} }}))"
        )

    eval_lua("(function() " + "; ".join(calls) + " end)()")


def bump_spawn_rule(
    workspace_id: str,
    window_class: str,
    x: int,
    y: int,
    width: int,
    height: int,
) -> None:
    """
    Adelanta la regla de esa clase al siguiente hueco, para que la
    proxima ventana nazca ya desplazada en vez de saltar despues.
    """
    if not window_class:
        return

    name = f"floatspawn-{workspace_id}-{window_class}-{int(time.time() * 1000)}"

    eval_lua(
        "hl.window_rule({ "
        f"name = {lua_string(name)}, "
        f"match = {{ class = {lua_string(window_class)}, "
        f"workspace = {lua_string(workspace_id)} }}, "
        "float = true, "
        f"move = {lua_string(f'{int(x)} {int(y)}')}, "
        f"size = {lua_string(f'{int(width)} {int(height)}')} "
        "})"
    )


def cascade_if_stacked(
    workspace_id: str,
    new_addresses: set[str],
) -> None:
    """
    Si una ventana nueva nace justo encima de otra (misma clase, misma
    posicion por regla), la baja y la corre a la derecha como en Windows.
    """
    if not new_addresses:
        return

    current = workspace_clients(workspace_id)

    for client in current:
        address = str(client.get("address", ""))

        if address not in new_addresses:
            continue

        if not client.get("floating", False):
            continue

        geo = geometry(client)

        if geo is None:
            continue

        # Posiciones ya ocupadas por otras flotantes del workspace.
        taken: list[dict[str, int]] = []

        for other in current:
            other_address = str(other.get("address", ""))

            if other_address == address or not other.get("floating", False):
                continue

            other_geo = geometry(other)

            if other_geo is not None:
                taken.append(other_geo)

        def collides(x: int, y: int) -> bool:
            return any(
                abs(g["x"] - x) <= CASCADE_TOLERANCE
                and abs(g["y"] - y) <= CASCADE_TOLERANCE
                for g in taken
            )

        target_x, target_y = geo["x"], geo["y"]
        attempts = 0

        # Baja en diagonal hasta encontrar un hueco libre.
        while collides(target_x, target_y) and attempts < 12:
            attempts += 1
            target_x = geo["x"] + CASCADE_OFFSET * attempts
            target_y = geo["y"] + CASCADE_OFFSET * attempts

        if attempts == 0:
            continue

        move_window(address, target_x, target_y)

        # Deja lista la posicion de la siguiente ventana de esta clase.
        bump_spawn_rule(
            workspace_id,
            str(client.get("class", "")),
            target_x + CASCADE_OFFSET,
            target_y + CASCADE_OFFSET,
            geo["width"],
            geo["height"],
        )


def geometry(client: dict[str, Any]) -> dict[str, int] | None:
    position = client.get("at")
    size = client.get("size")

    if not isinstance(position, list) or len(position) < 2:
        return None

    if not isinstance(size, list) or len(size) < 2:
        return None

    return {
        "x": int(position[0]),
        "y": int(position[1]),
        "width": int(size[0]),
        "height": int(size[1]),
    }


def save_workspace_geometry(workspace_id: str) -> None:
    layouts = load_json(LAYOUTS_FILE, {})
    workspace_layout = layouts.setdefault(workspace_id, {})

    for key, client in clients_with_keys(workspace_clients(workspace_id)):
        if not client.get("floating", False):
            continue

        current_geometry = geometry(client)

        # Ignora medidas absurdas: suelen venir de capturar la ventana
        # a media animacion de cierre o apertura.
        if (
            current_geometry is not None
            and current_geometry["width"] >= 200
            and current_geometry["height"] >= 150
        ):
            workspace_layout[key] = current_geometry

    save_json(LAYOUTS_FILE, layouts)


def restore_workspace_geometry(workspace_id: str) -> None:
    layouts = load_json(LAYOUTS_FILE, {})
    workspace_layout = layouts.get(workspace_id, {})

    if not workspace_layout:
        return

    current = clients_with_keys(workspace_clients(workspace_id))

    for key, client in current:
        saved = workspace_layout.get(key)

        if saved is None:
            continue

        address = str(client.get("address", ""))

        if not address:
            continue

        resize_window(
            address,
            saved["width"],
            saved["height"],
        )

        move_window(
            address,
            saved["x"],
            saved["y"],
        )


def enable_mode(workspace_id: str, runtime: dict[str, Any]) -> None:
    current = clients_with_keys(workspace_clients(workspace_id))

    original_states: dict[str, bool] = {}

    for key, client in current:
        original_states[key] = bool(client.get("floating", False))

    runtime["modes"][workspace_id] = {
        "original_floating": original_states,
        "rules": register_rules(workspace_id),
        "classes": covered_classes(workspace_id),
        "signature": geometry_signature(workspace_id),
    }
    save_json(RUNTIME_FILE, runtime)

    layouts = load_json(LAYOUTS_FILE, {})
    workspace_layout = layouts.get(workspace_id, {})

    for key, client in current:
        address = str(client.get("address", ""))

        if not address:
            continue

        float_and_place(address, workspace_layout.get(key))

    start_watcher()

    notify(
        "Floating mode",
        f"Workspace {workspace_id}: activado",
    )


def disable_mode(workspace_id: str, runtime: dict[str, Any]) -> None:
   """Desactiva floating y fuerza tiling absoluto en el workspace."""
   save_workspace_geometry(workspace_id)

   mode_data = runtime["modes"].get(workspace_id, {})

   # Quitar primero las reglas que fuerzan floating.
   disable_rules(mode_data.get("rules", []))

   # Desactivar el modo antes de normalizar las ventanas.
   runtime["modes"].pop(workspace_id, None)
   save_json(RUNTIME_FILE, runtime)

   # Repetir varias veces para cubrir ventanas restauradas,
   # desminimizadas o saliendo de fullscreen.
   for _attempt in range(4):
       changed = False

       for client in workspace_clients(workspace_id):
           address = str(client.get("address", ""))

           if not address:
               continue

           if client.get("floating", False):
               set_floating(address, False)
               changed = True

       if not changed:
           break

       time.sleep(0.12)

   notify(
       "Tiling mode",
       f"Workspace {workspace_id}: todas las ventanas en tiling",
   )


def watcher_running() -> bool:
    try:
        pid = int(WATCHER_PID_FILE.read_text(encoding="utf-8").strip())
        os.kill(pid, 0)
        return True
    except (FileNotFoundError, ValueError, ProcessLookupError, PermissionError):
        return False


def start_watcher() -> None:
    if watcher_running():
        return

    subprocess.Popen(
        [sys.executable, str(Path(__file__).resolve()), "--watch"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )


def watch() -> None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    WATCHER_PID_FILE.write_text(str(os.getpid()), encoding="utf-8")

    known_addresses: dict[str, set[str]] = {}
    last_save = 0.0

    try:
        while True:
            runtime = normalized_runtime()
            active_modes = runtime.get("modes", {})

            if not active_modes:
                break

            for workspace_id in list(active_modes):
                current = workspace_clients(workspace_id)
                current_addresses = {
                    str(client.get("address", ""))
                    for client in current
                    if client.get("address")
                }

                previous_addresses = known_addresses.setdefault(workspace_id, set())
                new_addresses = current_addresses - previous_addresses

                # Las ventanas cubiertas por una regla ya nacen bien;
                # tocarlas otra vez es justo lo que causaba el brinco.
                covered = set(active_modes.get(workspace_id, {}).get("classes", []))
                needs_restore = False

                for client in current:
                   address = str(client.get("address", ""))

                   if not address:
                      continue

                   # Mientras el modo esté activo, todas las ventanas
                   # de este workspace deben permanecer floating.
                   if not client.get("floating", False):
                      set_floating(address, True)

                   # Solo las ventanas nuevas necesitan restauración
                   # de geometría cuando su clase no está cubierta.
                   if (
                      address in new_addresses
                      and str(client.get("class", "")) not in covered
                   ):
                      needs_restore = True

                if needs_restore:
                    time.sleep(0.12)
                    restore_workspace_geometry(workspace_id)

                if new_addresses:
                    time.sleep(0.10)
                    cascade_if_stacked(workspace_id, new_addresses)

                known_addresses[workspace_id] = current_addresses

            now = time.monotonic()

            # Guarda periódicamente las posiciones mientras se mueven.
            if now - last_save >= 1.0:
                for workspace_id in list(active_modes):
                    save_workspace_geometry(workspace_id)
                    refresh_rules(workspace_id, runtime)

                last_save = now

            time.sleep(POLL_INTERVAL)

    finally:
        try:
            WATCHER_PID_FILE.unlink()
        except FileNotFoundError:
            pass


def toggle() -> None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)

    runtime = normalized_runtime()
    workspace_id = active_workspace_id()

    if workspace_id in runtime["modes"]:
        disable_mode(workspace_id, runtime)
    else:
        enable_mode(workspace_id, runtime)


def status() -> None:
    runtime = normalized_runtime()
    workspace_id = active_workspace_id()

    if workspace_id in runtime["modes"]:
        print(f"floating mode active on workspace {workspace_id}")
    else:
        print(f"floating mode inactive on workspace {workspace_id}")


def main() -> None:
    if len(sys.argv) > 1 and sys.argv[1] == "--watch":
        watch()
        return

    if len(sys.argv) > 1 and sys.argv[1] == "--status":
        status()
        return

    toggle()


if __name__ == "__main__":
    main()
