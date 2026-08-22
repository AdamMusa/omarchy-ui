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

  def test_renderer_whitelists_the_prototype_control_set
    qml = source("Service.qml")
    %w[text icon button row column container image spacer grid stack scroll rectangle
       action_button toggle toggle_switch text_field number_field slider dropdown
       multi_select button_group progress separator section_header].each do |type|
      assert_match(/^    #{type}: true,?$/, qml)
    end
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
end
