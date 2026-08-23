import QtQuick
import Quickshell

Item {
  id:clipboardRoot;property var renderer:null;property int handledRevision:-1
  function synchronize(){if(!renderer)return;var revision=Number(renderer.prop("revision",0));var requested=renderer.prop("text",null);if(requested!==null&&revision!==handledRevision){handledRevision=revision;Quickshell.clipboardText=String(requested);renderer.bridge.sendEvent(renderer.surfaceName,renderer.controlId,"copied",{value:String(requested),revision:revision})}}
  Component.onCompleted:synchronize();Connections{target:renderer;function onNodeChanged(){clipboardRoot.synchronize()}}
  Connections{target:Quickshell;enabled:renderer&&renderer.prop("watch",true)!==false;function onClipboardTextChanged(){renderer.bridge.sendEvent(renderer.surfaceName,renderer.controlId,"change",{value:Quickshell.clipboardText})}}
}
