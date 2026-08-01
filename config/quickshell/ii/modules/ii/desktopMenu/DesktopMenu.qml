pragma ComponentBehavior: Bound

// ---------------------------------------------------------------------------
//  DesktopMenu  (portado de end4-pC a ii, versión recortada y "tuya")
//  - Clic derecho en escritorio vacío -> tarjeta animada
//  - Carrusel de fotos: al hacer clic recolorea el tema (Wallpapers.select)
//
//  Solo depende de APIs que ya existen en tu ii base:
//    Wallpapers.select / randomFromCurrentFolder, GlobalStates.wallpaperSelectorOpen,
//    Directories.wallpaperSwitchScriptPath, Config.options.background.*
//  El estado vive en DesktopMenuState (singleton propio) -> no toca GlobalStates.
//  Quité GroupedList / DropShelf / submenús: dependían del fork.
// ---------------------------------------------------------------------------

import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
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

    function displayPathFor(path) {
        if (!path) return path
        return /\.(mp4|webm|mkv|avi|mov)$/i.test(path)
            ? Config.options.background.thumbnailPath
            : path
    }

    // Imágenes de la carpeta del wallpaper actual
    FolderListModel {
        id: wallpaperFolder
        folder: {
            const wallPath = Config.options.background.wallpaperPath
            if (!wallPath || wallPath.length === 0) return ""
            const lastSlash = wallPath.lastIndexOf("/")
            return "file://" + wallPath.substring(0, lastSlash)
        }
        showDirs: false
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
    }

    property int carouselExtraCount: 6
    property var randomWallpapers: {
        const current = FileUtils.trimFileProtocol(Config.options.background.wallpaperPath)
        let all = []
        for (let i = 0; i < wallpaperFolder.count; i++) {
            const fp = FileUtils.trimFileProtocol(wallpaperFolder.get(i, "filePath").toString())
            if (fp !== current) all.push(fp)
        }
        for (let i = all.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [all[i], all[j]] = [all[j], all[i]]
        }
        return all.slice(0, carouselExtraCount)
    }

    property var carouselModel: {
        const current = FileUtils.trimFileProtocol(Config.options.background.wallpaperPath)
        if (!current || current.length === 0) return randomWallpapers.map(p => root.displayPathFor(p))
        return [root.displayPathFor(current), ...randomWallpapers.map(p => root.displayPathFor(p))]
    }

    // Precarga silenciosa de los wallpapers del carrusel (para que abran al instante)
    Item {
        id: menuPreloader
        visible: false
        Repeater {
            model: root.carouselModel
            delegate: Image {
                required property var modelData
                source: modelData ? (modelData.startsWith("/") ? "file://" + modelData : modelData) : ""
                cache: true
                asynchronous: true
                visible: false
                sourceSize.width: 480
            }
        }
    }

    // Ventana del menú (una sola instancia)
    Loader {
        active: DesktopMenuState.menuOpen
        sourceComponent: PanelWindow {
            id: menuWindow
            screen: DesktopMenuState.menuScreen ?? Quickshell.screens[0]
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:desktopMenu"
            WlrLayershell.layer: WlrLayer.Overlay
            anchors { top: true; bottom: true; left: true; right: true }

            // Clic fuera => cerrar
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: DesktopMenuState.close()
            }

            // Tarjeta del menú
            Rectangle {
                id: menuCard
                width: 348
                implicitHeight: menuCol.implicitHeight + 16
                x: Math.min(Math.max(DesktopMenuState.menuX - width / 2, 8), menuWindow.width - width - 8)
                y: Math.min(Math.max(DesktopMenuState.menuY - implicitHeight / 2, 8), menuWindow.height - implicitHeight - 8)
                radius: Appearance.rounding.verylarge
                color: "transparent"

                opacity: 0
                // el menu "nace" del punto exacto del clic
                property real cardScale: 0.6
                property real originFx: Math.max(0, Math.min(1, (DesktopMenuState.menuX - x) / Math.max(1, width)))
                property real originFy: Math.max(0, Math.min(1, (DesktopMenuState.menuY - y) / Math.max(1, height)))
                transform: Scale {
                    origin.x: menuCard.width * menuCard.originFx
                    origin.y: menuCard.height * menuCard.originFy
                    xScale: menuCard.cardScale
                    yScale: menuCard.cardScale
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
                    NumberAnimation {
                        duration: Appearance.animationCurves.expressiveEffectsDuration
                        easing.type: Easing.OutQuad
                    }
                }

                // Absorbe clics dentro de la tarjeta
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

                ColumnLayout {
                    id: menuCol
                    anchors { fill: parent; margins: 8 }
                    spacing: 4

                    // --- Carrusel de fotos: clic = cambiar wallpaper + recolorear tema ---
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 160
                        radius: Appearance.rounding.verylarge
                        color: Appearance.colors.colLayer0
                        clip: true

                        Carousel {
                            anchors.fill: parent
                            anchors.margins: 10
                            model: root.carouselModel
                            onWallpaperSelected: (path) => {
                                Wallpapers.select(path, Appearance.m3colors.darkmode)
                                DesktopMenuState.close()
                            }
                        }
                    }

                    // --- Filas de acciones ---
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: rowsCol.implicitHeight + 8
                        radius: Appearance.rounding.verylarge
                        color: Appearance.colors.colLayer0

                        ColumnLayout {
                            id: rowsCol
                            anchors { fill: parent; margins: 4 }
                            spacing: 2

                            component MenuRow: RippleButton {
                                id: menuRowRoot
                                Layout.fillWidth: true
                                implicitHeight: 40
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer2
                                buttonRadius: Appearance.rounding.verylarge
                                property string rowIcon: ""
                                property string rowLabel: ""
                                contentItem: RowLayout {
                                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                    spacing: 12
                                    MaterialSymbol { text: menuRowRoot.rowIcon; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnLayer1 }
                                    StyledText { Layout.fillWidth: true; text: menuRowRoot.rowLabel; font.pixelSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colOnLayer1 }
                                }
                            }

                            MenuRow {
                                rowIcon: "shuffle"; rowLabel: Translation.tr("Fondo aleatorio")
                                onClicked: {
                                    Wallpapers.randomFromCurrentFolder(Appearance.m3colors.darkmode)
                                    DesktopMenuState.close()
                                }
                            }
                            MenuRow {
                                rowIcon: "wallpaper"; rowLabel: Translation.tr("Selector de fondos")
                                onClicked: {
                                    DesktopMenuState.close()
                                    GlobalStates.wallpaperSelectorOpen = true
                                }
                            }
                            MenuRow {
                                rowIcon: Appearance.m3colors.darkmode ? "light_mode" : "dark_mode"
                                rowLabel: Appearance.m3colors.darkmode ? Translation.tr("Modo claro") : Translation.tr("Modo oscuro")
                                onClicked: {
                                    DesktopMenuState.close()
                                    Quickshell.execDetached([Directories.wallpaperSwitchScriptPath,
                                        "--mode", Appearance.m3colors.darkmode ? "light" : "dark", "--noswitch"])
                                }
                            }
                            MenuRow {
                                rowIcon: "settings"
                                rowLabel: Translation.tr("Configuración")
                                onClicked: {
                                    DesktopMenuState.close()
                                    Quickshell.execDetached(["qs", "-p", Quickshell.shellPath("settings.qml")])
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
