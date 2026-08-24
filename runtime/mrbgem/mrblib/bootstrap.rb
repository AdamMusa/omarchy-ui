# frozen_string_literal: true

module Zui
  VERSION = "0.0.5" unless const_defined?(:VERSION)
  FRAMEWORK_ROOT = "" unless const_defined?(:FRAMEWORK_ROOT)

  class NativeStatus
    attr_reader :exitstatus
    def initialize(exitstatus) = @exitstatus = exitstatus
    def success? = exitstatus == 0
  end

  CommandResult = Struct.new(:stdout, :stderr, :status, keyword_init: true) do
    def success? = status.success?
    def exitstatus = status.exitstatus
  end

  class CommandTimeout < StandardError; end
  class CommandOutputLimit < StandardError; end

  module Command
    def self.run(argv, env: {}, chdir: nil, input: "", timeout: nil, max_output_bytes: 1_048_576)
      raise ArgumentError, "mruby command env is not implemented" unless env.empty?
      raise ArgumentError, "mruby command chdir is not implemented" if chdir
      raise ArgumentError, "mruby command input is not implemented" unless input.to_s.empty?
      limit = max_output_bytes.to_i
      raise ArgumentError, "max_output_bytes must be positive" unless limit.positive?
      result = Zui.native_command(argv, timeout ? timeout.to_f : 0, limit)
      raise CommandTimeout, "command timed out after #{timeout}s: #{argv.first}" if result["timed_out"]
      if result["output_limited"]
        raise CommandOutputLimit, "command output exceeded #{limit} bytes: #{argv.first}"
      end
      CommandResult.new(
        stdout: result["stdout"], stderr: result["stderr"],
        status: NativeStatus.new(result["status"])
      )
    end
  end

  # The embedded VM already contains Zui. Project-owned relative files are
  # loaded from the app root while nested require_relative calls keep their base.
  module SourceLoader
    @loaded = {}
    @stack = []

    def self.require_framework(feature)
      return false if feature == "zui" || feature == "omarchy_ui"

      raise LoadError, "cannot load such file -- #{feature}"
    end

    def self.require_relative(feature)
      base = if @stack.empty?
               ENV["OMARCHY_UI_PROJECT_DIR"] || ENV["ZUI_PROJECT_DIR"] || Dir.pwd
             else
               File.dirname(@stack.last)
             end
      path = File.expand_path(feature, base)
      path = "#{path}.rb" if File.extname(path).empty?
      return false if @loaded[path]
      raise LoadError, "cannot load such file -- #{path}" unless File.file?(path)

      @loaded[path] = true
      @stack << path
      loaded = false
      Object.class_eval(File.read(path))
      loaded = true
      true
    ensure
      @loaded.delete(path) if path && !loaded
      @stack.pop if path && @stack.last == path
    end
  end
end

module Kernel
  unless method_defined?(:require)
    def require(feature)
      Zui::SourceLoader.require_framework(feature)
    end
  end

  unless method_defined?(:require_relative)
    def require_relative(feature)
      Zui::SourceLoader.require_relative(feature)
    end
  end
end

# mruby runs one VM on one host thread. These locks preserve the public API
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
