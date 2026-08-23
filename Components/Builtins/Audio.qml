import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import QtMultimedia
import QtQuick.VectorImage
import qs.Commons
import qs.Ui as OmarchyUi

Item {
  required property var renderer
      id: audioRoot
      implicitWidth: 0
      implicitHeight: 0
      function syncPlayback() {
        var requested = String(renderer.prop("playback", ""))
        if (requested === "play") audioPlayer.play()
        else if (requested === "pause") audioPlayer.pause()
        else if (requested === "stop") audioPlayer.stop()
      }
      MediaPlayer {
        id: audioPlayer
        source: String(renderer.prop("source", ""))
        autoPlay: renderer.prop("auto_play", false) === true
        loops: Number(renderer.prop("loops", 1))
        playbackRate: Number(renderer.prop("playback_rate", 1))
        audioOutput: AudioOutput {
          volume: Math.max(0, Math.min(1, Number(renderer.prop("volume", 1))))
          muted: renderer.prop("muted", false) === true
        }
        onPlaybackStateChanged: function(playbackState) {
          var eventName = playbackState === MediaPlayer.PlayingState ? "play"
            : (playbackState === MediaPlayer.PausedState ? "pause" : "stop")
          renderer.bridge.sendEvent(renderer.surfaceName, renderer.controlId, eventName, {})
        }
        onErrorOccurred: function(error, message) {
          renderer.bridge.sendEvent(renderer.surfaceName, renderer.controlId, "error", { code: error, message: message })
        }
        onPositionChanged: {
          if (renderer.subscribed("position")) renderer.bridge.sendEvent(renderer.surfaceName, renderer.controlId, "position", { value: position, duration: duration })
        }
        onDurationChanged: {
          if (renderer.subscribed("duration")) renderer.bridge.sendEvent(renderer.surfaceName, renderer.controlId, "duration", { value: duration })
        }
      }
      Component.onCompleted: syncPlayback()
      Connections { target: root; function onNodeChanged() { audioRoot.syncPlayback() } }
    }
