import qs.modules.pc
import QtQuick
import qs.modules.common
import qs.modules.pc.widgets
import qs.services
import Quickshell.Io

QuickToggleButton {
    id: nightLightButton
    toggled: Hyprsunset.temperatureActive
    buttonIcon: PcConfig.options.light.night.automatic ? "night_sight_auto" : "bedtime"
    onClicked: {
        Hyprsunset.toggleTemperature()
    }

    altAction: () => {
        PcConfig.options.light.night.automatic = !PcConfig.options.light.night.automatic
    }

    Component.onCompleted: {
        Hyprsunset.fetchState()
    }
    
    StyledToolTip {
        text: Translation.tr("Night Light | Right-click to toggle Auto mode")
    }
}
