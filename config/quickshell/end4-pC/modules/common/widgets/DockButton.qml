import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RippleButton {
    Layout.fillHeight: true
    Layout.topMargin: Appearance.sizes.elevationMargin - Appearance.sizes.hyprlandGapsOut
    implicitWidth: implicitHeight - topInset - bottomInset
    buttonRadius: Appearance.rounding.normal

    background.implicitHeight: 50

    // Animacion de escala en hover/press (portada de ii)
    property real hoverScale: 1.12
    property real pressScale: 0.84
    property int scaleDuration: 520
    property real scaleOvershoot: 2.2

    transformOrigin: Item.Bottom
    scale: pressed ? pressScale : (hovered ? hoverScale : 1.0)
    Behavior on scale {
        NumberAnimation {
            duration: scaleDuration
            easing.type: Easing.OutBack
            easing.overshoot: scaleOvershoot
        }
    }
}