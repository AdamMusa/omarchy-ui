# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

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
      enable = !arguments.delete("--no-enable")
      restart = !arguments.delete("--no-restart")
      source = File.expand_path(arguments.shift || Dir.pwd)
      manifest_path = File.join(source, "manifest.json")
      manifest = JSON.parse(File.read(manifest_path))
      plugin_id = manifest.fetch("id")
      raise ArgumentError, "invalid plugin id" unless VALID_ID.match?(plugin_id)
      raise ArgumentError, "plugin validation failed" unless system("omarchy", "plugin", "validate", source)

      plugin_root = File.expand_path("~/.config/omarchy/plugins")
      destination = File.join(plugin_root, plugin_id)
      raise ArgumentError, "cannot push an installed plugin onto itself" if source == destination
      FileUtils.mkdir_p(plugin_root)
      backup = nil
      staging = Dir.mktmpdir(".#{plugin_id}.staging-", plugin_root)
      entries = Dir.children(source).reject { |entry| entry == ".git" }
      FileUtils.cp_r(entries.map { |entry| File.join(source, entry) }, staging)
      raise ArgumentError, "staged plugin validation failed" unless system("omarchy", "plugin", "validate", staging)

      if File.exist?(destination)
        backup = "#{destination}.backup-#{Time.now.strftime('%Y%m%d%H%M%S')}-#{Process.pid}"
        FileUtils.mv(destination, backup)
        @out.puts("Backed up existing plugin to #{backup}")
      end
      FileUtils.mv(staging, destination)
      staging = nil
      system("omarchy", "plugin", "enable", plugin_id) if enable
      system("omarchy", "restart", "shell") if restart
      @out.puts("Pushed #{plugin_id} to #{destination}")
      0
    rescue StandardError
      if backup && !File.exist?(destination) && File.exist?(backup)
        FileUtils.mv(backup, destination)
        @err.puts("Restored previous plugin after push failure")
      end
      raise
    ensure
      FileUtils.remove_entry(staging) if staging && File.exist?(staging)
    end
  end
end
