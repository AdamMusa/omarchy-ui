# frozen_string_literal: true

require "fileutils"
require "json"
require "tmpdir"

module OmarchyUI
  module Runtime
    module_function

    BUNDLED = File.expand_path("../../vendor/runtime/x86_64-linux/omarchy-ui-runtime", __dir__)
    ADAPTER_FILES = %w[Service.qml Panel.qml BarWidget.qml App.qml].freeze
    ZUI_GENERATED_ENTRIES = %w[Desktop.qml ControlNode.qml Components Controls Theme Fonts].freeze
    TREE_SHAKE_REPORT = "zui-tree-shake.json"
    SHELL_COMPONENT_ROOT = File.expand_path("../../qml", __dir__)
    SHELL_COMPONENTS = %w[DesktopStage.qml Positioned.qml].freeze
    FILES = (ADAPTER_FILES + %w[ControlNode.qml]).freeze
    LEGACY_METADATA_FILES = %W[
      #{TREE_SHAKE_REPORT}
      #{QmlCompiler::REPORT} #{QmlCompiler::CHECKSUM} #{QmlCompiler::PROVENANCE}
      omarchy-ui-runtime.sha256 runtime-provenance.json RUNTIME_PROVENANCE.md
    ].freeze
    GENERATED_ENTRIES = (ADAPTER_FILES + ZUI_GENERATED_ENTRIES + [
      QmlCompiler::COMPILED_ROOT,
      "omarchy-ui-runtime"
    ] + LEGACY_METADATA_FILES).freeze

    def executable
      override = ENV["OMARCHY_UI_RUNTIME"]
      return File.expand_path(override) if override && !override.empty?
      return BUNDLED if File.executable?(BUNDLED)
      "omarchy-ui-runtime"
    end

    def install_shared(destination: nil)
      destination ||= File.expand_path("~/.local/bin/omarchy-ui-runtime")
      raise ArgumentError, "bundled mruby runtime is missing" unless File.file?(BUNDLED)
      FileUtils.mkdir_p(File.dirname(destination))
      temporary = "#{destination}.install-#{Process.pid}"
      FileUtils.cp(BUNDLED, temporary)
      FileUtils.chmod(0o755, temporary)
      File.rename(temporary, destination)
      destination
    ensure
      FileUtils.rm_f(temporary) if temporary && File.exist?(temporary)
    end

    def install_package(path, framework_root: FRAMEWORK_ROOT, project: path, compiled: false)
      FileUtils.mkdir_p(path)
      GENERATED_ENTRIES.each do |entry|
        generated = File.join(path, entry)
        File.directory?(generated) ? FileUtils.remove_entry(generated) : FileUtils.rm_f(generated)
      end
      install_tree_shaken_zui(path, project:)
      ADAPTER_FILES.each do |file|
        FileUtils.cp(File.join(framework_root, file), File.join(path, file))
      end

      if File.file?(BUNDLED)
        destination = File.join(path, "omarchy-ui-runtime")
        FileUtils.cp(BUNDLED, destination)
        FileUtils.chmod(0o755, destination)
      end
      QmlCompiler.compile!(path, entry_files: package_entry_files(path)) if compiled
      path
    end

    def install_components(path, **options)
      install_package(path, **options)
    end

    def install_tree_shaken_zui(destination, project:)
      Dir.mktmpdir("omarchy-ui-zui-") do |temporary|
        qml = File.join(temporary, "qml")
        native = File.join(temporary, "native")
        FileUtils.mkdir_p(native)
        Zui::Runtime.install_qml(qml)
        report = Zui::TreeShaker.new(project:, framework: qml, native:).shake!
        install_shell_components(qml)
        FileUtils.rm_f([File.join(qml, "Desktop.qml"), File.join(qml, "Service.qml")])
        entries = Dir.children(qml).map { |entry| File.join(qml, entry) }
        FileUtils.cp_r(entries, destination) unless entries.empty?
        return report
      end
    end

    def package_entry_files(path)
      manifest_path = File.join(path, "manifest.json")
      return ["App.qml"] unless File.file?(manifest_path)

      manifest = JSON.parse(File.read(manifest_path))
      entries = manifest.fetch("entryPoints").values.map(&:to_s).uniq
      unknown = entries - QmlCompiler::ENTRY_TYPES.keys
      raise ArgumentError, "unsupported manifest QML entry points: #{unknown.join(', ')}" unless unknown.empty?
      raise ArgumentError, "manifest has no QML entry points" if entries.empty?

      entries
    rescue JSON::ParserError, KeyError, TypeError => error
      raise ArgumentError, "invalid plugin manifest: #{error.message}"
    end

    def install_shell_components(qml)
      builtins = File.join(qml, "Components", "Builtins")
      FileUtils.mkdir_p(builtins)
      SHELL_COMPONENTS.each do |file|
        FileUtils.cp(File.join(SHELL_COMPONENT_ROOT, file), File.join(builtins, file))
      end

      control_node = File.join(qml, "ControlNode.qml")
      source = File.read(control_node)
      source = source.sub(
        'readonly property bool builtIn: ["text"',
        'readonly property bool builtIn: ["desktop_stage", "positioned", "text"'
      )
      source = source.sub(
        'readonly property bool structuralContainer: ["row"',
        'readonly property bool structuralContainer: ["desktop_stage", "positioned", "row"'
      )
      source = source.sub(
        'return bridge && bridge.projectDir ? bridge.projectDir + "/" + source : Qt.resolvedUrl(source)',
        'return bridge && bridge.projectDir ? "file://" + bridge.projectDir + "/" + source : Qt.resolvedUrl(source)'
      )
      File.write(control_node, source)
    end
  end
end
