# frozen_string_literal: true

require "minitest/autorun"

class QmlContractTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def source(name)
    File.read(File.join(ROOT, name))
  end

  def test_service_uses_one_tracked_bidirectional_process_without_a_shell
    qml = source("Service.qml")
    assert_includes qml, "Process {"
    assert_includes qml, "stdinEnabled: true"
    assert_includes qml, "rubyProcess.write(JSON.stringify("
    assert_includes qml, "stdout: SplitParser"
    assert_includes qml, 'rubyProcess.command = ["ruby", rubyProgram]'
    refute_includes qml, "execDetached"
    refute_includes qml, '["bash"'
  end

  def test_renderer_installs_the_ruby_component_registry
    qml = source("Service.qml")
    assert_includes qml, "function validateComponents(components)"
    assert_includes qml, "componentDefinitions = validated"
    assert_includes qml, "allowedTypes = dynamicTypes"
    assert_includes qml, "allowedProperties = dynamicProperties"
  end

  def test_panel_exposes_omarchy_loader_lifecycle
    qml = source("Panel.qml")
    assert_match(/function open\(payloadJson\)/, qml)
    assert_match(/function close\(\)/, qml)
    assert_includes qml, "property var service: null"
  end

  def test_renderer_supports_validated_native_property_animations
    renderer = source("ControlNode.qml")
    service = source("Service.qml")
    assert_includes renderer, "PropertyAnimation { id: patchAnimation }"
    assert_includes renderer, "function easingType(name)"
    assert_includes service, 'return reject("patch animation rejected")'
    assert_includes service, "replacement.transition"
  end

  def test_component_lifecycle_events_require_explicit_subscriptions
    renderer = source("ControlNode.qml")
    service = source("Service.qml")
    assert_includes renderer, 'subscribed("mount")'
    assert_includes renderer, 'subscribed("unmount")'
    assert_includes service, "subscriptions.indexOf(eventName) < 0"
  end

  def test_renderer_uses_runtime_recursion_and_qualified_omarchy_types
    renderer = source("ControlNode.qml")
    panel = source("Panel.qml")
    refute_match(/^\s+ControlNode \{$/, renderer)
    assert_includes renderer, 'source: Qt.resolvedUrl("ControlNode.qml")'
    assert_includes renderer, "OmarchyUi.BorderSurface {"
    assert_includes panel, "OmarchyUi.BorderSurface {"
  end

  def test_service_validates_structural_child_patches
    service = source("Service.qml")
    assert_includes service, 'message.op === "replace_children"'
    assert_includes service, 'return reject("invalid children patch")'
    assert_includes service, "validateNode(message.children[childIndex]"
  end
end
