# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "rbconfig"

module OmarchyUI
  class CLI
    def self.run(arguments, out: $stdout, err: $stderr)
      new(out:, err:).run(arguments)
    end

    def initialize(out:, err:)
      @out = out
      @err = err
    end

    def run(arguments)
      command = arguments.shift
      case command
      when "run" then run_file(arguments)
      when "push" then push(arguments)
      when "validate" then validate(arguments)
      when "version", "--version", "-v" then @out.puts(OmarchyUI::VERSION); 0
      else
        @err.puts("Usage: omarchy_ui <run FILE|push [DIRECTORY]|validate [DIRECTORY]|version>")
        command.nil? ? 0 : 64
      end
    rescue ArgumentError, SystemCallError, JSON::ParserError => error
      @err.puts("omarchy_ui: #{error.message}")
      1
    end

    private

    def run_file(arguments)
      file = File.expand_path(arguments.shift || raise(ArgumentError, "run requires a Ruby file"))
      raise ArgumentError, "Ruby file not found: #{file}" unless File.file?(file)
      exec(RbConfig.ruby, file, *arguments)
    end

    def validate(arguments)
      source = File.expand_path(arguments.shift || Dir.pwd)
      system("omarchy", "plugin", "validate", source) ? 0 : 1
    end

    def push(arguments)
      source = File.expand_path(arguments.shift || Dir.pwd)
      manifest_path = File.join(source, "manifest.json")
      manifest = JSON.parse(File.read(manifest_path))
      plugin_id = manifest.fetch("id")
      raise ArgumentError, "invalid plugin id" unless VALID_ID.match?(plugin_id)
      raise ArgumentError, "plugin validation failed" unless system("omarchy", "plugin", "validate", source)

      plugin_root = File.expand_path("~/.config/omarchy/plugins")
      destination = File.join(plugin_root, plugin_id)
      FileUtils.mkdir_p(plugin_root)
      if File.exist?(destination)
        backup = "#{destination}.backup-#{Time.now.strftime('%Y%m%d%H%M%S')}"
        FileUtils.mv(destination, backup)
        @out.puts("Backed up existing plugin to #{backup}")
      end
      FileUtils.cp_r(source, destination)
      FileUtils.rm_rf(File.join(destination, ".git"))
      system("omarchy", "plugin", "enable", plugin_id)
      system("omarchy", "restart", "shell")
      @out.puts("Pushed #{plugin_id} to #{destination}")
      0
    end
  end
end
