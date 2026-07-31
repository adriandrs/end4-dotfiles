import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt.labs.synchronizer
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: overviewScope
    property bool dontAutoCancelSearch: false
    property bool workspaceView: false

    PanelWindow {
        id: panelWindow
        property string searchingText: ""
        readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
        property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)
        // La ventana sobrevive mientras el contenido se desvanece.
        visible: GlobalStates.overviewOpen || columnLayout.opacity > 0

        WlrLayershell.namespace: "quickshell:overview"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: GlobalStates.overviewOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        mask: Region {
            item: GlobalStates.overviewOpen ? columnLayout : null
        }

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // El Loader destruye el widget al cerrar, asi que la direccion
        // elegida se guarda aqui mientras el widget sigue vivo.
        property string pendingAddress: ""
        property int pendingWorkspace: -1

        function activeViewItem() {
            return overviewScope.workspaceView
                ? workspaceLoader.item
                : overviewLoader.item;
        }

        function commitSelection() {
            if (panelWindow.pendingWorkspace > 0) {
                const ws = panelWindow.pendingWorkspace;
                panelWindow.pendingWorkspace = -1;
                Hyprland.dispatch(`hl.dsp.focus({ workspace = ${ws} })`);
                return;
            }

            if (panelWindow.pendingAddress === "")
                return;

            const address = panelWindow.pendingAddress;
            panelWindow.pendingAddress = "";

            Hyprland.dispatch(`hl.dsp.focus({window = "address:${address}"})`);
            Hyprland.dispatch(`hl.dsp.window.alter_zorder({mode = "top", window = "address:${address}"})`);
        }

        Connections {
            target: GlobalStates
            function onOverviewOpenChanged() {
                if (!GlobalStates.overviewOpen) {
                    panelWindow.commitSelection();
                    searchWidget.disableExpandAnimation();
                    overviewScope.dontAutoCancelSearch = false;
                    GlobalFocusGrab.dismiss();
                } else {
                    panelWindow.pendingAddress = "";
                    panelWindow.pendingWorkspace = -1;
                    if (!overviewScope.dontAutoCancelSearch) {
                        searchWidget.cancelSearch();
                    }
                    GlobalFocusGrab.addDismissable(panelWindow);
                }
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                GlobalStates.overviewOpen = false;
            }
        }
        implicitWidth: columnLayout.implicitWidth
        implicitHeight: columnLayout.implicitHeight

        function setSearchingText(text) {
            searchWidget.setSearchingText(text);
            searchWidget.focusFirstItem();
        }

        Column {
            id: columnLayout
            // closeAnim: mantener visible mientras se desvanece al cerrar.
            visible: opacity > 0
            opacity: GlobalStates.overviewOpen ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            scale: GlobalStates.overviewOpen ? 1.0 : 0.78
            transformOrigin: Item.Top

            Behavior on scale {
                NumberAnimation {
                    duration: 380
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.7
                }
            }

            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
            }
            spacing: -8

            // Tab llega primero al foco del buscador; hay que reclamarlo antes.
            Keys.onShortcutOverride: event => {
                if (panelWindow.searchingText !== "")
                    return;

                if (event.key === Qt.Key_Tab
                    || event.key === Qt.Key_Backtab
                    || event.key === Qt.Key_Return
                    || event.key === Qt.Key_Enter) {
                    event.accepted = true;
                }
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    GlobalStates.overviewOpen = false;
                    return;
                }

                const widget = overviewLoader.item;

                // Con texto en el buscador, el teclado es del buscador.
                if (!widget || panelWindow.searchingText !== "")
                    return;

                if (event.key === Qt.Key_Tab) {
                    widget.selectStep(1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Backtab) {
                    widget.selectStep(-1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return
                        || event.key === Qt.Key_Enter) {
                    if (widget.activateSelected())
                        GlobalStates.overviewOpen = false;
                    event.accepted = true;
                }
            }

            SearchWidget {
                id: searchWidget
                anchors.horizontalCenter: parent.horizontalCenter

                onNavRequested: delta => {
                    const view = panelWindow.activeViewItem();
                    if (!view) return;

                    view.selectStep(delta);

                    if (view.selectedAddress) {
                        panelWindow.pendingAddress = view.selectedAddress();
                    } else if (view.selectedIndex !== undefined) {
                        panelWindow.pendingWorkspace =
                            view.workspaceGroup * view.workspacesShown
                            + view.selectedIndex + 1;
                    }
                }

                onActivateRequested: {
                    const view = panelWindow.activeViewItem();
                    if (view && view.activateSelected())
                        GlobalStates.overviewOpen = false;
                }
                Synchronizer on searchingText {
                    property alias source: panelWindow.searchingText
                }
            }

            // Boton Material You para alternar vista
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: panelWindow.searchingText == ""
                implicitWidth: toggleChip.implicitWidth
                implicitHeight: toggleChip.implicitHeight

                Rectangle {
                    id: toggleChip
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    implicitWidth: chipText.implicitWidth + 28
                    implicitHeight: chipText.implicitHeight + 14
                    radius: Appearance.rounding.full
                    color: overviewScope.workspaceView
                        ? Appearance.colors.colPrimary
                        : Appearance.m3colors.m3surfaceContainerHighest

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    StyledText {
                        id: chipText
                        anchors.centerIn: parent
                        text: overviewScope.workspaceView
                            ? "Vista ventanas"
                            : "Vista escritorios"
                        color: overviewScope.workspaceView
                            ? Appearance.m3colors.m3onPrimary
                            : Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.small
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: overviewScope.workspaceView = !overviewScope.workspaceView
                    }
                }
            }

            Loader {
                id: overviewLoader
                anchors.horizontalCenter: parent.horizontalCenter
                active: columnLayout.visible
                    && !overviewScope.workspaceView
                    && (Config?.options.overview.enable ?? true)
                sourceComponent: OverviewWidget {
                    screen: panelWindow.screen
                    visible: (panelWindow.searchingText == "")
                }
            }

            Loader {
                id: workspaceLoader
                anchors.horizontalCenter: parent.horizontalCenter
                active: columnLayout.visible
                    && overviewScope.workspaceView
                    && (Config?.options.overview.enable ?? true)
                // Sube la vista de escritorios. Mas negativo = mas arriba.
                property real wsShift: -180
                transform: Translate { y: workspaceLoader.wsShift }

                sourceComponent: OverviewWorkspaces {
                    screen: panelWindow.screen
                    visible: (panelWindow.searchingText == "")
                }
            }
        }
    }

    function toggleClipboard() {
        if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.overviewOpen = false;
            return;
        }
        overviewScope.dontAutoCancelSearch = true;
        panelWindow.setSearchingText(Config.options.search.prefix.clipboard);
        GlobalStates.overviewOpen = true;
    }

    function toggleEmojis() {
        if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.overviewOpen = false;
            return;
        }
        overviewScope.dontAutoCancelSearch = true;
        panelWindow.setSearchingText(Config.options.search.prefix.emojis);
        GlobalStates.overviewOpen = true;
    }

    IpcHandler {
        target: "search"

        function toggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function workspacesToggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function close() {
            GlobalStates.overviewOpen = false;
        }
        function open() {
            GlobalStates.overviewOpen = true;
        }
        function toggleReleaseInterrupt() {
            GlobalStates.superReleaseMightTrigger = false;
        }
        function clipboardToggle() {
            overviewScope.toggleClipboard();
        }
    }

    GlobalShortcut {
        name: "searchToggle"
        description: "Toggles search on press"

        onPressed: {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    GlobalShortcut {
        name: "overviewWorkspacesClose"
        description: "Closes overview on press"

        onPressed: {
            GlobalStates.overviewOpen = false;
        }
    }
    GlobalShortcut {
        name: "overviewWorkspacesToggle"
        description: "Toggles overview on press"

        onPressed: {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    GlobalShortcut {
        name: "searchToggleRelease"
        description: "Toggles search on release"

        onPressed: {
            GlobalStates.superReleaseMightTrigger = true;
        }

        onReleased: {
            if (!GlobalStates.superReleaseMightTrigger) {
                GlobalStates.superReleaseMightTrigger = true;
                return;
            }
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    GlobalShortcut {
        name: "searchToggleReleaseInterrupt"
        description: "Interrupts possibility of search being toggled on release. " + "This is necessary because GlobalShortcut.onReleased in quickshell triggers whether or not you press something else while holding the key. " + "To make sure this works consistently, use binditn = MODKEYS, catchall in an automatically triggered submap that includes everything."

        onPressed: {
            GlobalStates.superReleaseMightTrigger = false;
        }
    }
    GlobalShortcut {
        name: "overviewClipboardToggle"
        description: "Toggle clipboard query on overview widget"

        onPressed: {
            overviewScope.toggleClipboard();
        }
    }

    GlobalShortcut {
        name: "overviewEmojiToggle"
        description: "Toggle emoji query on overview widget"

        onPressed: {
            overviewScope.toggleEmojis();
        }
    }
}
