# frozen_string_literal: true

require "fileutils"

module OmarchyUI
  class Project
    RUNTIME_FILES = %w[Service.qml ControlNode.qml Panel.qml BarWidget.qml App.qml].freeze

    def initialize(path:, name: nil, framework_root: FRAMEWORK_ROOT)
      @path = File.expand_path(path)
      @name = name || File.basename(@path).split(/[-_]/).map(&:capitalize).join(" ")
      @framework_root = framework_root
    end

    def create
      raise ArgumentError, "destination already exists: #{@path}" if File.exist?(@path)
      created = true
      FileUtils.mkdir_p(File.join(@path, "Components"))
      File.write(File.join(@path, "main.rb"), main_program)
      File.write(File.join(@path, "Components", "Welcome.qml"), welcome_component)
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
      FileUtils.mkdir_p(File.join(path, "Components"))
    end

    private

    def main_program
      <<~RUBY
        # frozen_string_literal: true

        require "omarchy_ui" unless Object.const_defined?(:OmarchyUI)

        OmarchyUI.plugin do
          register_component :welcome,
            qml: "Welcome.qml",
            properties: %i[title message]

          app :main, title: "#{@name}", width: 760, height: 520 do
            component :welcome,
              title: "Welcome to #{@name}",
              message: "This is the official Omarchy UI framework."
          end
        end
      RUBY
    end

    def welcome_component
      <<~QML
        import QtQuick
        import qs.Commons
        import qs.Ui

        BorderSurface {
          id: root

          property string title: "Welcome"
          property string message: "This is the official Omarchy UI framework."

          implicitWidth: 520
          implicitHeight: 220
          color: Color.popups.background
          radius: Style.cornerRadius
          borderSpec: Border.controlSpec("normal", Color.foreground, Color.accent)

          Column {
            anchors.centerIn: parent
            spacing: Style.spacing.lg

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.title
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.heading
              font.bold: true
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.message
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }
          }
        }
      QML
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

        Edit `main.rb` for application state and behavior. Custom QML adapters live in
        `Components/`; `Welcome.qml` is included as a working example.
      MARKDOWN
    end
  end
end
