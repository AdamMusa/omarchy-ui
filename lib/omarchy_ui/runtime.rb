# frozen_string_literal: true

require "fileutils"

module OmarchyUI
  module Runtime
    module_function

    BUNDLED = File.expand_path("../../vendor/runtime/x86_64-linux/omarchy-ui-runtime", __dir__)

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
      FileUtils.cp(BUNDLED, destination)
      FileUtils.chmod(0o755, destination)
      destination
    end
  end
end
