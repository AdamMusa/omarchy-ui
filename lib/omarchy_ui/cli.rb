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
      when "launch" then launch_file(arguments)
      when "new" then new_project(arguments)
      when "bundle" then bundle_project(arguments)
      when "push" then push(arguments)
      when "validate" then validate(arguments)
      when "version", "--version", "-v" then @out.puts(OmarchyUI::VERSION); 0
      else
        @err.puts("Usage: omarchy_ui <new NAME|run FILE|launch FILE|bundle [DIRECTORY]|push [DIRECTORY]|validate [DIRECTORY]|version>")
        command.nil? ? 0 : 64
      end
    rescue Interrupt
      130
    rescue ArgumentError, SystemCallError, JSON::ParserError => error
      @err.puts("omarchy_ui: #{error.message}")
      1
    end

    private

    def run_file(arguments)
      file = File.expand_path(arguments.shift || raise(ArgumentError, "run requires a Ruby file"))
      raise ArgumentError, "Ruby file not found: #{file}" unless File.file?(file)
      exec(RbConfig.ruby, "-I", File.join(FRAMEWORK_ROOT, "lib"), file, *arguments)
    end

    def launch_file(arguments)
      file = File.expand_path(arguments.shift || raise(ArgumentError, "launch requires a Ruby file"))
      raise ArgumentError, "Ruby file not found: #{file}" unless File.file?(file)
      raise ArgumentError, "launch does not accept Ruby arguments" unless arguments.empty?

      project_dir = File.dirname(file)
      Dir.mktmpdir("omarchy-ui-app-") do |runtime_dir|
        Project::RUNTIME_FILES.each do |name|
          source = File.file?(File.join(project_dir, name)) ? File.join(project_dir, name) : File.join(FRAMEWORK_ROOT, name)
          FileUtils.cp(source, runtime_dir)
        end
        %w[Commons Ui].each do |module_name|
          source = File.join("/usr/share/omarchy/shell", module_name)
          raise ArgumentError, "Omarchy QML module not found: #{source}" unless File.directory?(source)
          FileUtils.ln_s(source, File.join(runtime_dir, module_name))
        end

        environment = ENV.to_h.merge(
          "OMARCHY_UI_PROJECT_DIR" => project_dir,
          "OMARCHY_UI_RUBY_PROGRAM" => file,
          "OMARCHY_UI_RUNTIME" => Runtime.executable,
          "QT_LOGGING_RULES" => qt_logging_rules
        )
        success = system(environment, "quickshell", "--path", File.join(runtime_dir, "App.qml"))
        return success ? 0 : ($?&.exitstatus || 1)
      end
    end

    def new_project(arguments)
      name = arguments.shift || raise(ArgumentError, "new requires a project name")
      raise ArgumentError, "new accepts only an application name" unless arguments.empty?
      destination = File.expand_path(slug(name))
      Project.new(path: destination, name: name).create
      @out.puts("Created standalone Omarchy UI app in #{destination}")
      0
    end

    def slug(value)
      result = value.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|\-\z/, "")
      raise ArgumentError, "name must contain letters or numbers" if result.empty?
      result
    end

    def validate(arguments)
      source = File.expand_path(arguments.shift || Dir.pwd)
      with_staged_project(source) do |staging|
        system("omarchy", "plugin", "validate", staging) ? 0 : 1
      end
    end

    def bundle_project(arguments)
      source = File.expand_path(arguments.shift || Dir.pwd)
      raise ArgumentError, "bundle accepts one directory" unless arguments.empty?
      raise ArgumentError, "main.rb not found: #{source}" unless File.file?(File.join(source, "main.rb"))
      destination = File.join(source, "dist", File.basename(source))
      raise ArgumentError, "bundle destination already exists: #{destination}" if File.exist?(destination)
      FileUtils.mkdir_p(destination)
      entries = Dir.children(source).reject { |entry| %w[.git dist].include?(entry) }
      FileUtils.cp_r(entries.map { |entry| File.join(source, entry) }, destination)
      Project.install_runtime(destination)
      runtime = File.join(destination, "omarchy-ui-runtime")
      FileUtils.cp(Runtime::BUNDLED, runtime)
      FileUtils.chmod(0o755, runtime)
      %w[Commons Ui].each do |module_name|
        FileUtils.ln_s(File.join("/usr/share/omarchy/shell", module_name), File.join(destination, module_name))
      end
      launcher = File.join(destination, "run")
      File.write(launcher, <<~SH)
        #!/bin/sh
        set -eu
        app_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
        export OMARCHY_UI_RUNTIME="$app_dir/omarchy-ui-runtime"
        export OMARCHY_UI_PROJECT_DIR="$app_dir"
        export OMARCHY_UI_RUBY_PROGRAM="$app_dir/main.rb"
        export QT_LOGGING_RULES="${QT_LOGGING_RULES:+$QT_LOGGING_RULES;}qt.qpa.services.warning=false"
        exec quickshell --path "$app_dir/App.qml"
      SH
      FileUtils.chmod(0o755, launcher)
      @out.puts("Bundled application in #{destination}")
      0
    rescue StandardError
      FileUtils.remove_entry(destination) if destination && File.directory?(destination)
      raise
    end

    def qt_logging_rules
      [ENV["QT_LOGGING_RULES"], "qt.qpa.services.warning=false"].compact.reject(&:empty?).join(";")
    end

    def push(arguments)
      enable = !arguments.delete("--no-enable")
      restart = !arguments.delete("--no-restart")
      source = File.expand_path(arguments.shift || Dir.pwd)
      Runtime.install_shared
      manifest_path = File.join(source, "manifest.json")
      manifest = JSON.parse(File.read(manifest_path))
      plugin_id = manifest.fetch("id")
      raise ArgumentError, "invalid plugin id" unless VALID_ID.match?(plugin_id)
      plugin_root = File.expand_path("~/.config/omarchy/plugins")
      backup_root = File.expand_path("~/.local/state/omarchy-ui/backups")
      destination = File.join(plugin_root, plugin_id)
      raise ArgumentError, "cannot push an installed plugin onto itself" if source == destination
      FileUtils.mkdir_p(plugin_root)
      backup = nil
      staging = stage_project(source, parent: plugin_root, prefix: ".#{plugin_id}.staging-")
      raise ArgumentError, "staged plugin validation failed" unless system("omarchy", "plugin", "validate", staging)

      if File.exist?(destination)
        FileUtils.mkdir_p(backup_root)
        backup = File.join(backup_root, "#{plugin_id}-#{Time.now.strftime('%Y%m%d%H%M%S')}-#{Process.pid}")
        FileUtils.mv(destination, backup)
        @out.puts("Backed up existing plugin to #{backup}")
      end
      FileUtils.mv(staging, destination)
      staging = nil
      activate_plugin(plugin_id) if enable
      raise ArgumentError, "shell restart failed; plugin is installed but not active" if restart && !system("omarchy", "restart", "shell")
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

    def with_staged_project(source)
      staging = stage_project(source)
      yield staging
    ensure
      FileUtils.remove_entry(staging) if staging && File.exist?(staging)
    end

    def stage_project(source, parent: nil, prefix: ".omarchy-ui-staging-")
      raise ArgumentError, "project directory not found: #{source}" unless File.directory?(source)
      staging = parent ? Dir.mktmpdir(prefix, parent) : Dir.mktmpdir(prefix)
      entries = Dir.children(source).reject { |entry| entry == ".git" }
      FileUtils.cp_r(entries.map { |entry| File.join(source, entry) }, staging) unless entries.empty?
      Project.install_runtime(staging) if File.file?(File.join(staging, "main.rb"))
      staging
    rescue StandardError
      FileUtils.remove_entry(staging) if staging && File.exist?(staging)
      raise
    end

    def activate_plugin(plugin_id)
      return if system("omarchy", "plugin", "enable", plugin_id)
      system("omarchy-shell", "shell", "rescanPlugins")
      20.times do
        return if system("omarchy", "plugin", "enable", plugin_id, out: File::NULL, err: File::NULL)
        sleep(0.1)
      end
      raise ArgumentError, "plugin was installed but Omarchy could not enable #{plugin_id}"
    end
  end
end
