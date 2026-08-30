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
    FILES = (ADAPTER_FILES + %w[ControlNode.qml]).freeze
    AUDIT_FILES = %w[
      omarchy-ui-runtime.sha256 runtime-provenance.json RUNTIME_PROVENANCE.md
    ].freeze
    GENERATED_ENTRIES = (ADAPTER_FILES + ZUI_GENERATED_ENTRIES +
      [TREE_SHAKE_REPORT, "omarchy-ui-runtime"]).freeze

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

    def install_package(path, framework_root: FRAMEWORK_ROOT, project: path)
      FileUtils.mkdir_p(path)
      GENERATED_ENTRIES.each do |entry|
        generated = File.join(path, entry)
        File.directory?(generated) ? FileUtils.remove_entry(generated) : FileUtils.rm_f(generated)
      end
      report = install_tree_shaken_zui(path, project:)
      ADAPTER_FILES.each do |file|
        FileUtils.cp(File.join(framework_root, file), File.join(path, file))
      end
      File.write(File.join(path, TREE_SHAKE_REPORT), JSON.pretty_generate({
        "zui_version" => Zui::VERSION,
        "components" => report.components.map(&:to_s),
        "before_bytes" => report.before_bytes,
        "after_bytes" => report.after_bytes,
        "saved_bytes" => report.saved_bytes,
        "warnings" => report.warnings
      }) + "\n")

      if File.file?(BUNDLED)
        destination = File.join(path, "omarchy-ui-runtime")
        FileUtils.cp(BUNDLED, destination)
        FileUtils.chmod(0o755, destination)
      end
      AUDIT_FILES.each do |file|
        source = File.join(framework_root, "vendor", "runtime", "x86_64-linux", file)
        FileUtils.cp(source, File.join(path, file)) if File.file?(source)
      end
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
        FileUtils.rm_f([File.join(qml, "Desktop.qml"), File.join(qml, "Service.qml")])
        entries = Dir.children(qml).map { |entry| File.join(qml, entry) }
        FileUtils.cp_r(entries, destination) unless entries.empty?
        return report
      end
    end
  end
end
