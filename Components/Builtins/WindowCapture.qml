import QtQuick
import QtMultimedia

Item {
  id:windowRoot;property var renderer:null;property alias windowCapture:nativeCapture;property int handledCommandRevision:-1
  function selectedWindow(){var windows=nativeCapture.capturableWindows();var requested=renderer?renderer.prop("window",0):0;if(typeof requested==="number")return requested>=0&&requested<windows.length?windows[requested]:undefined;for(var i=0;i<windows.length;i++)if(String(windows[i].id)===String(requested)||windows[i].description===String(requested))return windows[i];return windows.length?windows[0]:undefined}
  function synchronizeWindow(){var selected=selectedWindow();if(selected!==undefined)nativeCapture.window=selected}
  function command(){if(!renderer)return;var revision=Number(renderer.prop("command_revision",0));if(revision===handledCommandRevision)return;handledCommandRevision=revision;var value=String(renderer.prop("command",""));if(value==="start")nativeCapture.start();else if(value==="stop")nativeCapture.stop()}
  WindowCapture{id:nativeCapture;active:renderer&&renderer.prop("active",false)===true;onActiveChanged:if(renderer)renderer.bridge.sendEvent(renderer.surfaceName,renderer.controlId,active?"start":"stop",{});onErrorOccurred:function(error,errorString){renderer.bridge.sendEvent(renderer.surfaceName,renderer.controlId,"error",{code:error,message:errorString})}}
  Component.onCompleted:{synchronizeWindow();command()} Connections{target:renderer;function onNodeChanged(){windowRoot.synchronizeWindow();windowRoot.command()}}
}
