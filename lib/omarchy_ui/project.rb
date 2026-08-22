# frozen_string_literal: true

require "fileutils"

module OmarchyUI
  class Project
    RUNTIME_FILES = %w[Service.qml ControlNode.qml Panel.qml BarWidget.qml App.qml].freeze
    RUNTIME_AUDIT_FILES = %w[omarchy-ui-runtime.sha256 RUNTIME_PROVENANCE.md].freeze

    def initialize(path:, name: nil, framework_root: FRAMEWORK_ROOT)
      @path = File.expand_path(path)
      @name = name || File.basename(@path).split(/[-_]/).map(&:capitalize).join(" ")
      @framework_root = framework_root
    end

    def create
      raise ArgumentError, "destination already exists: #{@path}" if File.exist?(@path)
      created = true
      FileUtils.mkdir_p(File.join(@path, "components"))
      File.write(File.join(@path, "main.rb"), main_program)
      File.write(File.join(@path, "components", "welcome.rb"), welcome_component)
      File.write(File.join(@path, "README.md"), readme)
      @path
    rescue StandardError
      FileUtils.remove_entry(@path) if created && File.directory?(@path)
      raise
    end

    def self.install_runtime(path, framework_root: FRAMEWORK_ROOT)
      RUNTIME_FILES.each do |file|
        destination = File.join(path, file)
        FileUtils.cp(File.join(framework_root, file), destination)
      end
      bundled_runtime = File.join(framework_root, "vendor", "runtime", "x86_64-linux", "omarchy-ui-runtime")
      if File.file?(bundled_runtime)
        destination = File.join(path, "omarchy-ui-runtime")
        FileUtils.cp(bundled_runtime, destination)
        FileUtils.chmod(0o755, destination)
      end
      RUNTIME_AUDIT_FILES.each do |file|
        source = File.join(framework_root, "vendor", "runtime", "x86_64-linux", file)
        FileUtils.cp(source, File.join(path, file)) if File.file?(source)
      end
      FileUtils.mkdir_p(File.join(path, "Components"))
    end

    private

    def main_program
      <<~RUBY
        # frozen_string_literal: true

        require "omarchy_ui" unless Object.const_defined?(:OmarchyUI)
        eval(File.read(File.join(File.dirname(__FILE__), "components", "welcome.rb")))

        OmarchyUI.plugin do
          app :main, title: "#{@name}", width: 760, height: 520 do
            welcome_card(
              title: "Welcome to #{@name}",
              message: "This is the official Omarchy UI framework."
            )
          end
        end
      RUBY
    end

    def welcome_component
      <<~RUBY
        # frozen_string_literal: true

        module WelcomeComponent
          def welcome_card(title:, message:)
            container padding: 24, bordered: true do
              column spacing: 12 do
                text title, style: :heading
                text message, wrap: true
              end
            end
          end
        end

        OmarchyUI::Builder.include(WelcomeComponent)
      RUBY
    end

    def readme
      <<~MARKDOWN
        # #{@name}

        A standalone application built with the official Omarchy UI framework.

        ## Run

        ```bash
        omarchy_ui launch main.rb
        ```

        The shared `omarchy-ui-runtime` must be installed on `PATH`. No system Ruby,
        application manifest, or copied framework QML files are required.

        Edit `main.rb` for application state and behavior. Reusable Ruby UI components live in
        `components/`; `welcome.rb` is included as a working example. `omarchy_ui bundle` generates
        the native QML bridge and embeds the runtime for distribution.
      MARKDOWN
    end
  end
end
