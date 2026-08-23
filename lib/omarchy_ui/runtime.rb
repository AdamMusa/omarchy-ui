# frozen_string_literal: true

require "fileutils"

module OmarchyUI
  module Runtime
    module_function

    BUNDLED = File.expand_path("../../vendor/runtime/x86_64-linux/omarchy-ui-runtime", __dir__)
    FILES = %w[Service.qml ControlNode.qml Panel.qml BarWidget.qml App.qml].freeze
    AUDIT_FILES = %w[omarchy-ui-runtime.sha256 RUNTIME_PROVENANCE.md].freeze

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
      FILES.each { |file| FileUtils.cp(File.join(framework_root, file), File.join(path, file)) }
      install_components(path, framework_root:)

      if File.file?(BUNDLED)
        destination = File.join(path, "omarchy-ui-runtime")
        FileUtils.cp(BUNDLED, destination)
        FileUtils.chmod(0o755, destination)
      end
      AUDIT_FILES.each do |file|
        source = File.join(framework_root, "vendor", "runtime", "x86_64-linux", file)
        FileUtils.cp(source, File.join(path, file)) if File.file?(source)
      end
    end

    def install_components(path, framework_root: FRAMEWORK_ROOT)
      destination = File.join(path, "Components")
      FileUtils.mkdir_p(destination)
      source = File.join(framework_root, "Components", "Builtins")
      FileUtils.cp_r(source, destination) if Dir.exist?(source)
    end
  end
end
