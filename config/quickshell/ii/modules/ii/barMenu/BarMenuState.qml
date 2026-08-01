pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell

Singleton {
    id: root
    property bool menuOpen: false
    property var  menuScreen: null
    property real menuX: 0
    property real menuY: 0

    function openAt(screen, x, y) {
        root.menuScreen = screen
        root.menuX = x
        root.menuY = y
        root.menuOpen = true
    }
    function close() { root.menuOpen = false }
}
