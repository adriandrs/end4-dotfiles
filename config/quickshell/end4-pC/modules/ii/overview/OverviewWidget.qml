pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
    id: root

    required property var screen

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property var windowByAddress: HyprlandData.windowByAddress
    readonly property var monitors: HyprlandData.monitors

    property bool currentWorkspaceOnly: true

    readonly property int activeWorkspaceId:
        HyprlandData.activeWorkspace?.id
            ?? Hyprland.focusedWorkspace?.id
            ?? root.monitor?.activeWorkspace?.id
            ?? 1

    readonly property var visibleWindows: {
        const wsId = root.activeWorkspaceId;
        const onlyCurrent = root.currentWorkspaceOnly;

        return ToplevelManager.toplevels.values.filter(toplevel => {
            const address = `0x${toplevel.HyprlandToplevel?.address}`;
            const window = root.windowByAddress[address];

            if (!window || !window.address || window.mapped === false)
                return false;

            const id = window.workspace?.id ?? 0;

            if (id < 1)
                return false;

            return onlyCurrent ? (id === wsId) : (id > 0);
        });
    }

    readonly property int windowCount: visibleWindows.length
    readonly property int maxColumns: 5
    readonly property int rowCount: Math.max(1, Math.ceil(windowCount / maxColumns))

    property real cardWidth: 250
    property real cardHeight: 155
    property real cardSpacing: 10
    property real outerPadding: 12

    // Indice de la tarjeta seleccionada con Tab. -1 = ninguna.
    property int selectedIndex: -1

    function selectStep(delta) {
        if (root.windowCount === 0) {
            root.selectedIndex = -1;
            return;
        }

        if (root.selectedIndex < 0) {
            root.selectedIndex = (delta > 0) ? 0 : root.windowCount - 1;
            return;
        }

        root.selectedIndex =
            (root.selectedIndex + delta + root.windowCount) % root.windowCount;
    }

    function selectedAddress() {
        if (root.selectedIndex < 0 || root.selectedIndex >= root.windowCount)
            return "";

        const raw = root.visibleWindows[root.selectedIndex]?.HyprlandToplevel?.address;
        return raw ? `0x${raw}` : "";
    }

    function activateSelected() {
        if (root.selectedIndex < 0 || root.selectedIndex >= root.windowCount)
            return false;

        const toplevel = root.visibleWindows[root.selectedIndex];
        const raw = toplevel?.HyprlandToplevel?.address;

        if (!raw)
            return false;

        const address = `0x${raw}`;

        Hyprland.dispatch(`hl.dsp.focus({window = "address:${address}"})`);
        Hyprland.dispatch(`hl.dsp.window.alter_zorder({mode = "top", window = "address:${address}"})`);

        return true;
    }

    Component.onCompleted: {
        for (let i = 0; i < root.visibleWindows.length; i++) {
            if (root.visibleWindows[i]?.activated) {
                root.selectedIndex = i;
                return;
            }
        }
        root.selectedIndex = root.windowCount > 0 ? 0 : -1;
    }

    implicitWidth: overviewBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: overviewBackground.implicitHeight + Appearance.sizes.elevationMargin * 2

    StyledRectangularShadow {
        target: overviewBackground
    }

    Rectangle {
        id: overviewBackground

        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin

        implicitWidth: windowRows.implicitWidth + root.outerPadding * 2
        implicitHeight: windowRows.implicitHeight + root.outerPadding * 2

        radius: Appearance.rounding.large
        color: Appearance.colors.colBackgroundSurfaceContainer

        Column {
            id: windowRows

            anchors.centerIn: parent
            spacing: root.cardSpacing

            Repeater {
                model: root.rowCount

                delegate: Row {
                    id: windowRow

                    required property int index

                    readonly property int rowStart:
                        windowRow.index * root.maxColumns

                    readonly property int windowsRemaining:
                        root.windowCount - rowStart

                    readonly property int itemsInRow:
                        Math.max(0, Math.min(root.maxColumns, windowsRemaining))

                    spacing: root.cardSpacing

                    anchors.horizontalCenter: parent.horizontalCenter

                    Repeater {
                        model: windowRow.itemsInRow

                        delegate: Rectangle {
                            id: card

                            required property int index

                            readonly property int globalIndex:
                                windowRow.rowStart + index

                            readonly property var toplevel:
                                root.visibleWindows[globalIndex]

                            readonly property string address:
                                `0x${toplevel?.HyprlandToplevel?.address}`

                            readonly property var windowData:
                                root.windowByAddress[address]

                            readonly property var sourceMonitor:
                                root.monitors.find(
                                    monitor => monitor.id === windowData?.monitor
                                ) ?? root.monitor

                            width: root.cardWidth
                            height: root.cardHeight

                            radius: Appearance.rounding.normal
                            color: Appearance.colors.colSurfaceContainerLow

                            border.width: (windowMouse.containsMouse
                                || card.globalIndex === root.selectedIndex) ? 3 : 1
                            border.color: card.globalIndex === root.selectedIndex
                                ? Appearance.colors.colPrimary
                                : windowMouse.containsMouse
                                    ? Appearance.colors.colSecondary
                                    : ColorUtils.transparentize(
                                        Appearance.colors.colOnLayer1,
                                        0.88
                                    )

                            Behavior on border.width {
                                NumberAnimation { duration: 120 }
                            }

                            clip: true

                            OverviewWindow {
                                id: preview

                                toplevel: card.toplevel
                                windowData: card.windowData
                                monitorData: card.sourceMonitor
                                widgetMonitor: card.sourceMonitor

                                restrictToWorkspace: false
                                centerIcons: true

                                scale: {
                                    const sourceWidth =
                                        Math.max(1, card.windowData?.size?.[0] ?? 1);

                                    const sourceHeight =
                                        Math.max(1, card.windowData?.size?.[1] ?? 1);

                                    const availableWidth = card.width - 12;
                                    const availableHeight = card.height - 12;

                                    return Math.min(
                                        availableWidth / sourceWidth,
                                        availableHeight / sourceHeight
                                    );
                                }

                                x: Math.round((card.width - width) / 2)
                                y: Math.round((card.height - height) / 2)

                                topLeftRadius: Appearance.rounding.small
                                topRightRadius: Appearance.rounding.small
                                bottomLeftRadius: Appearance.rounding.small
                                bottomRightRadius: Appearance.rounding.small
                            }

                            Rectangle {
                                visible: false

                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    bottom: parent.bottom
                                }

                                height: titleText.implicitHeight + 12

                                color: "transparent" 

                                StyledText {
                                    id: titleText

                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        verticalCenter: parent.verticalCenter
                                        margins: 8
                                    }

                                    text: card.windowData?.title
                                        || card.windowData?.class
                                        || "Ventana"

                                    color: Appearance.colors.colOnLayer0
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                            }

                            MouseArea {
                                id: windowMouse

                                anchors.fill: parent
                                hoverEnabled: true

                                acceptedButtons:
                                    Qt.LeftButton | Qt.RightButton

                                cursorShape: Qt.PointingHandCursor

                                onClicked: mouse => {
                                    if (!card.windowData?.address)
                                        return;

                                    if (mouse.button === Qt.LeftButton) {
                                        const address = card.windowData.address;

                                        GlobalStates.overviewOpen = false;

                                        Hyprland.dispatch(
                                            `hl.dsp.focus({window = "address:${address}"})`
                                        );

                                        Hyprland.dispatch(
                                            `hl.dsp.window.alter_zorder({mode = "top", window = "address:${address}"})`
                                        );

                                        mouse.accepted = true;
                                    } else if (mouse.button === Qt.RightButton) {
                                        Hyprland.dispatch(
                                            `hl.dsp.window.close({window = "address:${card.windowData.address}"})`
                                        );

                                        mouse.accepted = true;
                                    }
                                }
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.2
                                }
                            }

                            scale: windowMouse.pressed ? 0.96 : 1
                        }
                    }
                }
            }

            StyledText {
                visible: root.windowCount === 0

                anchors.horizontalCenter: parent.horizontalCenter

                text: "No hay ventanas abiertas"
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.normal
            }
        }
    }
}
