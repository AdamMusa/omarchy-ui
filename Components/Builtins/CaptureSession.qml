import QtQuick
import QtMultimedia

Item {
  id:sessionRoot;property var renderer:null;property alias captureSession:nativeSession;property alias camera:nativeCamera;property alias imageCapture:nativeImageCapture;property alias mediaRecorder:nativeRecorder;property alias audioInput:nativeAudioInput;property alias audioOutput:nativeAudioOutput
  function device(list,requested,fallback){var value=String(requested||"");for(var index=0;index<list.length;index++)if(String(list[index].id)===value||list[index].description===value)return list[index];return fallback}
  implicitWidth:Number(renderer?renderer.prop("width",640):640);implicitHeight:Number(renderer?renderer.prop("height",360):360)
  Camera{id:nativeCamera;active:renderer&&renderer.prop("camera_active",false)===true}
  MediaDevices{id:nativeDevices}
  AudioInput{id:nativeAudioInput;device:sessionRoot.device(nativeDevices.audioInputs,renderer?renderer.prop("audio_input_device",""):"",nativeDevices.defaultAudioInput)}
  AudioOutput{id:nativeAudioOutput;device:sessionRoot.device(nativeDevices.audioOutputs,renderer?renderer.prop("audio_output_device",""):"",nativeDevices.defaultAudioOutput)}
  ImageCapture{id:nativeImageCapture}
  MediaRecorder{id:nativeRecorder}
  CaptureSession{id:nativeSession;camera:nativeCamera;audioInput:nativeAudioInput;audioOutput:nativeAudioOutput;imageCapture:nativeImageCapture;recorder:nativeRecorder;videoOutput:renderer&&renderer.prop("video_output_enabled",true)!==false?nativeVideoOutput:null}
  VideoOutput{id:nativeVideoOutput;anchors.fill:parent;visible:renderer&&renderer.prop("video_output_enabled",true)!==false}
  Item{anchors.fill:parent;Repeater{model:renderer?(renderer.node.children||[]):[];delegate:renderer.childDelegateComponent}}
  Component.onCompleted:if(renderer)renderer.bridge.sendEvent(renderer.surfaceName,renderer.controlId,"ready",{})
}
