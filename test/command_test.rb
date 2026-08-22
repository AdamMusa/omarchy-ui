# frozen_string_literal: true

require "minitest/autorun"
require "rbconfig"
require_relative "../lib/omarchy_ui"

class CommandTest < Minitest::Test
  def test_command_uses_argv_without_shell_interpolation
    payload = "$(touch /tmp/omarchy-ui-must-not-exist);`echo nope`"
    result = OmarchyUI::Command.run([RbConfig.ruby, "-e", "print ARGV.fetch(0)", payload])
    assert result.success?
    assert_equal payload, result.stdout
    refute File.exist?("/tmp/omarchy-ui-must-not-exist")
  end

  def test_command_captures_failure_status_and_stderr
    result = OmarchyUI::Command.run([RbConfig.ruby, "-e", "warn 'bad'; exit 7"])
    refute result.success?
    assert_equal 7, result.exitstatus
    assert_equal "bad\n", result.stderr
  end

  def test_command_timeout_terminates_the_child
    assert_raises(OmarchyUI::CommandTimeout) do
      OmarchyUI::Command.run([RbConfig.ruby, "-e", "sleep 5"], timeout: 0.02)
    end
  end
end
