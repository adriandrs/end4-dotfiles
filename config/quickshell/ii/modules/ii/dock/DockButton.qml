import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: dockButton

    // ─────────── AJUSTES ───────────
    // Cuanto crece el icono al pasar el cursor. 1.0 = sin efecto.
    // Sutil 1.10 · normal 1.18 · marcado 1.30
    property real hoverScale: 1.12

    // Cuanto se encoge al hacer clic. 1.0 = sin efecto.
    property real pressScale: 0.84

    // Duracion en ms de la animacion de escala. Menos = mas seco.
    property int scaleDuration: 520

    // Rebote al crecer. 0 = sin rebote, 3 = muy elastico.
    property real scaleOvershoot: 2.2

    // Altura del boton en px. Cambia el tamaño general del dock.
    property real buttonHeight: 50

    // Redondeo de las esquinas.
    // Alternativas: Appearance.rounding.small / large / full
    property real cornerRadius: Appearance.rounding.full

    // Separacion vertical respecto al borde de la pantalla.
    property real topSpacing: Appearance.sizes.elevationMargin
        - Appearance.sizes.hyprlandGapsOut

    // Punto desde el que crece. Item.Bottom hace que el icono "suba".
    // Alternativas: Item.Center, Item.Top
    property int growOrigin: Item.Bottom
    // ────────── FIN AJUSTES ──────────

    Layout.fillHeight: true
    Layout.topMargin: dockButton.topSpacing
    implicitWidth: implicitHeight - topInset - bottomInset
    buttonRadius: dockButton.cornerRadius
    background.implicitHeight: dockButton.buttonHeight

    transformOrigin: dockButton.growOrigin

    scale: pressed
        ? dockButton.pressScale
        : (hovered ? dockButton.hoverScale : 1.0)

    Behavior on scale {
        NumberAnimation {
            duration: dockButton.scaleDuration
            easing.type: Easing.OutBack
            easing.overshoot: dockButton.scaleOvershoot
        }
    }
}
