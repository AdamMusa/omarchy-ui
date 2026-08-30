# frozen_string_literal: true

module OmarchyUI
  module RuntimeAudit
    MAX_FILE_BYTES = 131_072
    MAX_EVENT_BYTES = 2_048

    def self.record_http(argv, native_result, duration_ms)
      metadata = http_metadata(argv)
      return unless metadata
      plugin_id = current_plugin_id
      return unless plugin_id
      root = File.expand_path("~/.local/state/omarchy-ui-audit")
      create_directory(root)
      path = File.join(root, "#{plugin_id}.jsonl")
      return if File.symlink?(path)
      event = {
        "v" => 1,
        "type" => "http",
        "method" => metadata["method"],
        "url" => metadata["url"],
        "http_status" => 0,
        "exit_status" => native_result["status"].to_i,
        "duration_ms" => [[duration_ms.to_i, 0].max, 3_600_000].min,
        "response_bytes" => [native_result["stdout"].to_s.bytesize, 1_048_576].min,
        "timed_out" => native_result["timed_out"] == true,
        "output_limited" => native_result["output_limited"] == true,
        "observed_at" => Time.now.to_i
      }
      line = JSON.generate(event)
      return if line.bytesize > MAX_EVENT_BYTES
      mode = File.file?(path) && File.size(path) + line.bytesize + 1 <= MAX_FILE_BYTES ? "a" : "w"
      File.open(path, mode, 0o600) { |file| file.write(line); file.write("\n") }
    rescue JSON::ParserError, SystemCallError, StandardError
      nil
    end

    def self.http_metadata(argv)
      return nil unless argv.is_a?(Array) && !argv.empty?
      command = File.basename(argv.first.to_s)
      return nil unless command == "curl" || command == "wget"
      raw_url = argv.find { |argument| argument.to_s.start_with?("http://", "https://") }
      url = redact_url(raw_url)
      return nil if url.empty?
      method = "GET"
      argv.each_with_index do |argument, index|
        value = argument.to_s
        if %w[-X --request].include?(value) && argv[index + 1]
          method = argv[index + 1].to_s.upcase.byteslice(0, 12)
        elsif value == "--post-data" || value.start_with?("--post-data=") ||
              %w[-d --data --data-raw --data-binary --data-urlencode -F --form].include?(value)
          method = "POST" if method == "GET"
        end
      end
      { "method" => method, "url" => url }
    end

    def self.redact_url(value)
      url = value.to_s.byteslice(0, 512).to_s
      query_index = url.index("?")
      fragment_index = url.index("#")
      ending = [query_index, fragment_index].compact.min
      url = url.byteslice(0, ending).to_s if ending
      scheme, remainder = url.split("://")
      return "" unless %w[http https].include?(scheme) && remainder
      parts = remainder.split("/")
      authority = parts.shift.to_s.split("@").last.to_s
      return "" if authority.empty?
      path = parts.join("/")
      "#{scheme}://#{authority}#{path.empty? ? "" : "/#{path}"}".byteslice(0, 300).to_s
    end

    def self.current_plugin_id
      manifest_path = File.join(Dir.pwd, "manifest.json")
      return nil unless File.file?(manifest_path) && !File.symlink?(manifest_path)
      parsed = JSON.parse(File.read(manifest_path, 16_384))
      plugin_id = parsed["id"].to_s
      valid = !plugin_id.empty? && plugin_id.bytesize <= 120
      plugin_id.each_byte do |byte|
        allowed = (byte >= 48 && byte <= 57) || (byte >= 65 && byte <= 90) ||
          (byte >= 97 && byte <= 122) || [45, 46, 58, 95].include?(byte)
        valid = false unless allowed
      end
      valid ? plugin_id : nil
    rescue JSON::ParserError, SystemCallError
      nil
    end

    def self.create_directory(path)
      current = path.start_with?(File::SEPARATOR) ? File::SEPARATOR : ""
      path.split(File::SEPARATOR).each do |part|
        next if part.empty?
        current = File.join(current, part)
        Dir.mkdir(current, 0o700) unless File.directory?(current)
      end
    end

  end
end

module Zui
  VERSION = "0.0.10" unless const_defined?(:VERSION)
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
      started_at = Time.now.to_f
      result = Zui.native_command(argv, timeout ? timeout.to_f : 0, limit)
      OmarchyUI::RuntimeAudit.record_http(argv, result, (Time.now.to_f - started_at) * 1000)
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
