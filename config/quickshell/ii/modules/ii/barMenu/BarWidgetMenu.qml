pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Scope {
    id: root

    function moveAllToWorkspace1() {
        Quickshell.execDetached(["bash", "-c",
            "ws=\$(hyprctl -j activeworkspace | jq -r .id); hyprctl -j clients | jq -r --argjson w \$ws '.[] | select(.workspace.id==\$w) | .address' | while read a; do hyprctl dispatch movetoworkspacesilent 1,address:\$a; done; hyprctl dispatch workspace 1"])
    }

    function closeAllWindows() {
        Quickshell.execDetached(["bash", "-c",
            "hyprctl -j clients | jq -r '.[].address' | while read a; do hyprctl dispatch closewindow address:$a; done"])
    }

    readonly property var entries: [
        { key: "activeWindow", icon: "select_window",   label: Translation.tr("Active window") },
        { key: "resources",    icon: "memory",          label: Translation.tr("Resources") },
        { key: "media",        icon: "music_note",      label: Translation.tr("Media") },
        { key: "workspaces",   icon: "grid_view",       label: Translation.tr("Workspaces") },
        { key: "clock",        icon: "schedule",        label: Translation.tr("Clock") },
        { key: "utilButtons",  icon: "widgets",         label: Translation.tr("Utility buttons") },
        { key: "battery",      icon: "battery_full",    label: Translation.tr("Battery") }
    ]

    Loader {
        active: BarMenuState.menuOpen
        sourceComponent: PanelWindow {
            id: menuWindow
            screen: BarMenuState.menuScreen ?? Quickshell.screens[0]
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:barMenu"
            WlrLayershell.layer: WlrLayer.Overlay
            anchors { top: true; bottom: true; left: true; right: true }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: BarMenuState.close()
            }

            Rectangle {
                id: card
                width: 280
                implicitHeight: col.implicitHeight + 16
                x: Math.min(Math.max(BarMenuState.menuX - 12, 8), menuWindow.width - width - 8)
                y: Math.min(Math.max(BarMenuState.menuY + 8, 8), menuWindow.height - implicitHeight - 8)
                radius: Appearance.rounding.verylarge
                color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.25)

                opacity: 0
                property real cardScale: 0.7
                transform: Scale {
                    origin.x: 20
                    origin.y: 0
                    xScale: card.cardScale
                    yScale: card.cardScale
                }
                Component.onCompleted: { cardScale = 1.0; opacity = 1.0 }
                Behavior on cardScale {
                    NumberAnimation {
                        duration: Appearance.animationCurves.expressiveDefaultSpatialDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
                    }
                }
                Behavior on opacity {
                    NumberAnimation { duration: Appearance.animationCurves.expressiveEffectsDuration }
                }

                MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

                ColumnLayout {
                    id: col
                    anchors { fill: parent; margins: 8 }
                    spacing: 2

                    StyledText {
                        Layout.leftMargin: 10
                        Layout.topMargin: 4
                        Layout.bottomMargin: 2
                        text: Translation.tr("Bar sections")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }

                    Repeater {
                        model: root.entries
                        delegate: RippleButton {
                            id: rowBtn
                            required property var modelData
                            readonly property bool on: Config.options.bar.barWidgets[modelData.key] ?? true
                            Layout.fillWidth: true
                            implicitHeight: 40
                            buttonRadius: Appearance.rounding.verylarge
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colLayer2
                            onClicked: {
                                Config.options.bar.barWidgets[rowBtn.modelData.key] = !rowBtn.on;
                            }
                            contentItem: RowLayout {
                                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                spacing: 12
                                MaterialSymbol {
                                    text: rowBtn.modelData.icon
                                    iconSize: Appearance.font.pixelSize.larger
                                    color: Appearance.colors.colOnLayer1
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: rowBtn.modelData.label
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colOnLayer1
                                }
                                MaterialSymbol {
                                    text: "check"
                                    iconSize: Appearance.font.pixelSize.normal
                                    fill: 1
                                    opacity: rowBtn.on ? 1 : 0
                                    color: Appearance.colors.colPrimary
                                    Behavior on opacity {
                                        NumberAnimation { duration: 120 }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { // separador
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        Layout.bottomMargin: 4
                        implicitHeight: 1
                        color: Appearance.colors.colOutlineVariant
                    }

                    RippleButton {
                        Layout.fillWidth: true
                        implicitHeight: 40
                        buttonRadius: Appearance.rounding.verylarge
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colLayer2
                        onClicked: {
                            BarMenuState.close()
                            Quickshell.execDetached(["hyprctl","dispatch","workspace","1"])
                        }
                        contentItem: RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            spacing: 12
                            MaterialSymbol {
                                text: "first_page"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colOnLayer1
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("Go to workspace 1")
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colOnLayer1
                            }
                        }
                    }

                    RippleButton {
                        Layout.fillWidth: true
                        implicitHeight: 40
                        buttonRadius: Appearance.rounding.verylarge
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colLayer2
                        onClicked: {
                            BarMenuState.close()
                            root.moveAllToWorkspace1()
                        }
                        contentItem: RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            spacing: 12
                            MaterialSymbol { text: "move_group"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnLayer1 }
                            StyledText { Layout.fillWidth: true; text: Translation.tr("Move all here to workspace 1"); font.pixelSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colOnLayer1 }
                        }
                    }

                    RippleButton {
                        Layout.fillWidth: true
                        implicitHeight: 40
                        buttonRadius: Appearance.rounding.verylarge
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colLayer2
                        onClicked: {
                            BarMenuState.close()
                            root.closeAllWindows()
                        }
                        contentItem: RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            spacing: 12
                            MaterialSymbol {
                                text: "close"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colError
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("Close all windows")
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colError
                            }
                        }
                    }
                }
            }
        }
    }
}
