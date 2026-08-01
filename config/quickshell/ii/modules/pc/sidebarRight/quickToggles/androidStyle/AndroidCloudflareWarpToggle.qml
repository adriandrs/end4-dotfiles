import qs.modules.common
import qs.modules.common.models.quickToggles
import qs.modules.pc.widgets
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io

AndroidQuickToggleButton {
    id: root

    toggleModel: CloudflareWarpToggle {}
}
