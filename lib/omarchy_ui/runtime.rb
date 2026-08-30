# frozen_string_literal: true

require "fileutils"

module OmarchyUI
  module Runtime
    module_function

    BUNDLED = File.expand_path("../../vendor/runtime/x86_64-linux/omarchy-ui-runtime", __dir__)
    ADAPTER_FILES = %w[Service.qml Panel.qml BarWidget.qml App.qml].freeze
    CORE_FILES = %w[ControlNode.qml Components Controls Theme Fonts].freeze
    FILES = (ADAPTER_FILES + ["ControlNode.qml"]).freeze
    AUDIT_FILES = %w[
      omarchy-ui-runtime.sha256 runtime-provenance.json RUNTIME_PROVENANCE.md
    ].freeze
    GENERATED_ENTRIES = (ADAPTER_FILES + CORE_FILES + %w[Desktop.qml omarchy-ui-runtime]).freeze

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

    def install_package(path, framework_root: FRAMEWORK_ROOT)
      Zui::Runtime.install_qml(path)
      FileUtils.rm_f(File.join(path, "Desktop.qml"))
      ADAPTER_FILES.each do |file|
        FileUtils.cp(File.join(framework_root, file), File.join(path, file))
      end

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

    def install_components(path, **)
      Zui::Runtime.install_qml(path)
      FileUtils.rm_f(File.join(path, "Desktop.qml"))
      path
    end
  end
end
