# frozen_string_literal: true

require "fileutils"
require "json"

module OmarchyUI
  class Project
    RUNTIME_FILES = %w[Service.qml ControlNode.qml Panel.qml BarWidget.qml].freeze

    def initialize(path:, id:, name: nil, framework_root: FRAMEWORK_ROOT)
      @path = File.expand_path(path)
      @id = id.to_s
      @name = name || File.basename(@path).split(/[-_]/).map(&:capitalize).join(" ")
      @framework_root = framework_root
      raise ArgumentError, "invalid plugin id: #{@id.inspect}" unless VALID_ID.match?(@id)
    end

    def create
      raise ArgumentError, "destination already exists: #{@path}" if File.exist?(@path)
      created = true
      FileUtils.mkdir_p(File.join(@path, "Components"))
      self.class.install_runtime(@path, framework_root: @framework_root)
      File.write(File.join(@path, "manifest.json"), JSON.pretty_generate(manifest) + "\n")
      File.write(File.join(@path, "main.rb"), main_program)
      File.write(File.join(@path, ".gitignore"), "*.log\n")
      @path
    rescue StandardError
      FileUtils.remove_entry(@path) if created && File.directory?(@path)
      raise
    end

    def self.install_runtime(path, framework_root: FRAMEWORK_ROOT)
      RUNTIME_FILES.each do |file|
        destination = File.join(path, file)
        FileUtils.cp(File.join(framework_root, file), destination) unless File.exist?(destination)
      end
      FileUtils.mkdir_p(File.join(path, "Components"))
      vendor_root = File.join(path, "vendor", "omarchy_ui")
      unless File.directory?(File.join(path, "lib", "omarchy_ui")) || File.directory?(File.join(vendor_root, "lib"))
        FileUtils.mkdir_p(vendor_root)
        FileUtils.cp_r(File.join(framework_root, "lib"), vendor_root)
      end
    end

    private

    def manifest
      {
        "schemaVersion" => 1,
        "id" => @id,
        "name" => @name,
        "version" => "0.1.0",
        "author" => "Ruby application",
        "license" => "MIT",
        "description" => "Ruby application powered by Omarchy UI",
        "kinds" => %w[service bar-widget panel],
        "keepLoaded" => true,
        "entryPoints" => {
          "service" => "Service.qml",
          "barWidget" => "BarWidget.qml",
          "panel" => "Panel.qml"
        },
        "barWidget" => {
          "displayName" => @name,
          "description" => "Open #{@name}",
          "category" => "Utilities",
          "allowMultiple" => false,
          "defaultSection" => "right"
        }
      }
    end

    def main_program
      <<~RUBY
        # frozen_string_literal: true

        begin
          require "omarchy_ui"
        rescue LoadError
          require_relative "vendor/omarchy_ui/lib/omarchy_ui"
        end

        OmarchyUI.plugin do
          bar_widget do
            text "#{@name}"
            on_click { open_panel :main }
          end

          panel :main do
            column spacing: 12 do
              text "#{@name}", style: :heading
              text "Built with Ruby and Omarchy UI"
            end
          end
        end
      RUBY
    end
  end
end
