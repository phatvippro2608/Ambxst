pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.config

Item {
    id: root
    property var sourceItem: null  // The icon item to tint
    property bool fullTint: false  // If true, apply solid primary color instead of shader

    property bool active: Config.tintIcons

    Loader {
        active: root.active
        anchors.fill: parent
        sourceComponent: Item {
            anchors.fill: parent

            ShaderEffectSource {
                id: internalSource
                sourceItem: root.sourceItem
                hideSource: true
                live: false  // Static content - use scheduleUpdate() when source changes
            }
            
            // Update texture when sourceItem changes
            Connections {
                target: root.sourceItem
                function onSourceChanged() { internalSource.scheduleUpdate(); }
                function onStatusChanged() { internalSource.scheduleUpdate(); }
            }
            
            // Also update when this component becomes visible or sourceItem changes
            Connections {
                target: root
                function onSourceItemChanged() { internalSource.scheduleUpdate(); }
                function onVisibleChanged() { if (root.visible) internalSource.scheduleUpdate(); }
            }

            // Full tint fallback (solid color)
            MultiEffect {
                visible: root.fullTint
                anchors.fill: parent
                source: internalSource
                brightness: 1.0
                colorization: 1.0
                colorizationColor: Styling.srItem("overprimary")
            }

            // Shader-based tint
            ShaderEffect {
                visible: !root.fullTint
                anchors.fill: parent
                
                property var source: internalSource
                property var paletteTexture: Colors.paletteTexture
                property real paletteSize: Colors.optimizedPalette.length
                property real texWidth: root.width
                property real texHeight: root.height

                vertexShader: "../widgets/dashboard/wallpapers/palette.vert.qsb"
                fragmentShader: "../widgets/dashboard/wallpapers/palette.frag.qsb"
            }
        }
    }
}

