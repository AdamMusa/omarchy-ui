import QtQuick
import "Support/OptionalModuleState.js" as OptionalModuleState

Item {
    id: modelHost

    required property var renderer
    property bool failureReported: false
    property bool moduleUnavailable: OptionalModuleState.quick3dUnavailable

    function reportUnavailable() {
        if (failureReported || !renderer.subscribed("error"))
            return ;

        failureReported = true;
        renderer.bridge.sendEvent(renderer.surfaceName, renderer.controlId, "error", {
            "code": "qtquick3d_unavailable",
            "message": "Qt Quick 3D is not installed. Install qt6-quick3d and assimp."
        });
    }

    implicitWidth: Number(renderer.prop("width", 420))
    implicitHeight: Number(renderer.prop("height", 420))
    clip: true
    Component.onCompleted: {
        if (OptionalModuleState.quick3dUnavailable) {
            moduleUnavailable = true;
            reportUnavailable();
            return ;
        }
        sceneLoader.setSource(Qt.resolvedUrl("Support/ModelView3dScene.qml"), {
            "renderer": renderer
        });
    }

    Rectangle {
        anchors.fill: parent
        color: renderer.prop("background", "transparent")
    }

    Image {
        id: fallbackImage

        anchors.fill: parent
        visible: sceneLoader.status !== Loader.Ready
        source: renderer.assetUrl(renderer.prop("fallback_source", ""))
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        smooth: true
        mipmap: true
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 18
        height: 42
        visible: String(renderer.prop("fallback_text", "")).length > 0 && (modelHost.moduleUnavailable || sceneLoader.status === Loader.Error)
        color: "#d9141b28"
        radius: 10
        border.width: 1
        border.color: renderer.prop("accent", "#ff6f7d")

        Text {
            anchors.fill: parent
            anchors.margins: 9
            text: renderer.prop("fallback_text", "")
            color: renderer.prop("foreground", "white")
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

    }

    Loader {
        id: sceneLoader

        anchors.fill: parent
        asynchronous: true
        onStatusChanged: {
            if (status === Loader.Error) {
                OptionalModuleState.quick3dUnavailable = true;
                modelHost.moduleUnavailable = true;
                modelHost.reportUnavailable();
            }
        }
    }

}
