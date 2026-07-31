import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

DockButton {
    id: root
    property var appToplevel
    property var appListRoot
    property int lastFocused: -1
    property real iconSize: 33
    property real countDotWidth: 10
    property real countDotHeight: 4
    property bool appIsActive: appToplevel.toplevels.find(t => (t.activated == true)) !== undefined

    readonly property bool isSeparator: appToplevel.appId === "SEPARATOR"
    property var desktopEntry: DesktopEntries.heuristicLookup(appToplevel.appId)
    enabled: !isSeparator
    implicitWidth: isSeparator ? 1 : implicitHeight - topInset - bottomInset

    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            root.desktopEntry = DesktopEntries.heuristicLookup(appToplevel.appId);
        }
    }

    Loader {
        active: isSeparator
        anchors {
            fill: parent
            topMargin: dockVisualBackground.margin + dockRow.padding + Appearance.rounding.normal
            bottomMargin: dockVisualBackground.margin + dockRow.padding + Appearance.rounding.normal
        }
        sourceComponent: DockSeparator {}
    }

    Loader {
        anchors.fill: parent
        active: appToplevel.toplevels.length > 0
        sourceComponent: MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onEntered: {
                appListRoot.lastHoveredButton = root
                appListRoot.buttonHovered = true
                lastFocused = appToplevel.toplevels.length - 1
            }
            onExited: {
                if (appListRoot.lastHoveredButton === root) {
                    appListRoot.buttonHovered = false
                }
            }
        }
    }

    readonly property int minimizeOffset: 1000
    function addressOf(toplevel) {
        const raw = toplevel?.HyprlandToplevel?.address;
        return raw ? `0x${raw}` : "";
    }
    function raiseWindow(address) {
        Hyprland.dispatch(`hl.dsp.focus({window = "address:${address}"})`);
        Hyprland.dispatch(`hl.dsp.window.alter_zorder({mode = "top", window = "address:${address}"})`);
    }
    onClicked: {
        if (appToplevel.toplevels.length === 0) {
            root.desktopEntry?.execute();
            return;
        }
        const currentWs = HyprlandData.activeWorkspace?.id ?? 1;
        const candidatesHere = appToplevel.toplevels.filter(tl => {
            const raw = tl?.HyprlandToplevel?.address;
            if (!raw) return false;
            const data = HyprlandData.windowByAddress[`0x${raw}`];
            const id = data?.workspace?.id ?? 0;
            return id > 0 && (id % 1000) === (currentWs % 1000);
        });
        const pool = candidatesHere.length > 0 ? candidatesHere : appToplevel.toplevels;
        lastFocused = (lastFocused + 1) % pool.length;
        const target = pool[lastFocused];
        const address = root.addressOf(target);
        if (address === "") {
            target.activate();
            return;
        }
        const workspaceId = HyprlandData.windowByAddress[address]?.workspace?.id ?? 0;
        if (workspaceId > root.minimizeOffset) {
            const originalWorkspace = workspaceId % root.minimizeOffset;
            Hyprland.dispatch(`hl.dsp.window.move({workspace = "${originalWorkspace}", window = "address:${address}", follow = false})`);
            root.raiseWindow(address);
        } else if (workspaceId < 1) {
            target.activate();
        } else if (target.activated) {
            Hyprland.dispatch(`hl.dsp.window.move({workspace = "${workspaceId + root.minimizeOffset}", window = "address:${address}", follow = false})`);
        } else {
            root.raiseWindow(address);
        }
    }

    middleClickAction: () => {
        root.desktopEntry?.execute();
    }

    altAction: () => {
        TaskbarApps.togglePin(appToplevel.appId);
    }

    contentItem: Loader {
        active: !isSeparator
        sourceComponent: Item {
            anchors.centerIn: parent

            Loader {
                id: iconImageLoader
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                active: !root.isSeparator
                sourceComponent: IconImage {
                    source: Quickshell.iconPath(AppSearch.guessIcon(appToplevel.appId), "image-missing")
                    implicitSize: root.iconSize
                }
            }

            Loader {
                active: Config.options.dock.monochromeIcons
                anchors.fill: iconImageLoader
                sourceComponent: Item {
                    Desaturate {
                        id: desaturatedIcon
                        visible: false // There's already color overlay
                        anchors.fill: parent
                        source: iconImageLoader
                        desaturation: 0.8
                    }
                    ColorOverlay {
                        anchors.fill: desaturatedIcon
                        source: desaturatedIcon
                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9)
                    }
                }
            }

            RowLayout {
                spacing: 3
                anchors {
                    top: iconImageLoader.bottom
                    topMargin: 2
                    horizontalCenter: parent.horizontalCenter
                }
                Repeater {
                    model: Math.min(appToplevel.toplevels.length, 3)
                    delegate: Rectangle {
                        required property int index
                        radius: Appearance.rounding.full
                        implicitWidth: (appToplevel.toplevels.length <= 3) ? 
                            root.countDotWidth : root.countDotHeight // Circles when too many
                        implicitHeight: root.countDotHeight
                        color: appIsActive ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.4)
                    }
                }
            }
        }
    }
}