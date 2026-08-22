# frozen_string_literal: true

module OmarchyUI
  VERSION = "0.4.0" unless const_defined?(:VERSION)
  FRAMEWORK_ROOT = "" unless const_defined?(:FRAMEWORK_ROOT)
end

module OmarchyUI
  class NativeStatus
    attr_reader :exitstatus
    def initialize(exitstatus) = @exitstatus = exitstatus
    def success? = exitstatus == 0
  end

  NativeCommandResult = Struct.new(:stdout, :stderr, :status, keyword_init: true) do
    def success? = status.success?
    def exitstatus = status.exitstatus
  end
end

module OmarchyUI::Command
  def self.run(argv, env: {}, chdir: nil, input: "", timeout: nil)
    raise ArgumentError, "mruby command env is not implemented" unless env.empty?
    raise ArgumentError, "mruby command chdir is not implemented" if chdir
    raise ArgumentError, "mruby command input is not implemented" unless input.to_s.empty?
    result = OmarchyUI.native_command(argv, timeout ? timeout.to_f : 0)
    if result["timed_out"]
      raise OmarchyUI::CommandTimeout, "command timed out after #{timeout}s: #{argv.first}"
    end
    OmarchyUI::NativeCommandResult.new(
      stdout: result["stdout"], stderr: result["stderr"],
      status: OmarchyUI::NativeStatus.new(result["status"])
    )
  end
end

module OmarchyUI
  class CommandTimeout < StandardError; end unless const_defined?(:CommandTimeout)
end

# mruby runs one VM on one host thread. These locks preserve the framework API
# while the native event loop serializes protocol, state, and timer callbacks.
class Mutex
  def synchronize
    yield
  end
end

class ConditionVariable
  def wait(_mutex, seconds = nil)
    sleep(seconds) if seconds && seconds > 0
  end

  def broadcast; end
end
