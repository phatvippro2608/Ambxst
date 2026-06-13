import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.config

Item {
    id: root
    property string source: ""
    property real radius: 0
    property bool tintEnabled: false
    
    // Container for masking (rounded corners)
    Item {
        anchors.fill: parent
        layer.enabled: root.radius > 0
        layer.effect: MultiEffect {
            maskEnabled: true
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
            maskSource: ShaderEffectSource {
                sourceItem: Rectangle {
                    width: root.width
                    height: root.height
                    radius: root.radius
                }
            }
        }

        Image {
            mipmap: true
            id: rawImage
            anchors.fill: parent
            source: root.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            
            // Tint layer
            layer.enabled: root.tintEnabled
            layer.effect: ShaderEffect {
                property var paletteTexture: Colors.paletteTexture
                property real paletteSize: Colors.optimizedPalette.length
                property real texWidth: rawImage.width
                property real texHeight: rawImage.height

                vertexShader: "../widgets/dashboard/wallpapers/palette.vert.qsb"
                fragmentShader: "../widgets/dashboard/wallpapers/palette.frag.qsb"
            }
        }
    }
}

