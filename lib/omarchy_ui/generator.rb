# frozen_string_literal: true

require "fileutils"

module OmarchyUI
  class Generator
    def initialize(path:, name: nil)
      @path = File.expand_path(path)
      @name = name || File.basename(@path).split(/[-_]/).map(&:capitalize).join(" ")
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

    private

    def main_program
      <<~RUBY
        # frozen_string_literal: true

        require "omarchy_ui"
        require_relative "components/welcome"

        OmarchyUI.app do
          app :main, title: "#{@name}", width: 760, height: 520 do
            welcome_card(
              title: "Welcome to #{@name}",
              message: "This Omarchy app is powered by the Zui framework."
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

        A pure Ruby Omarchy application built with Zui through the Omarchy UI adapter.

        ## Run

        ```bash
        omarchy_ui launch main.rb
        ```

        Reusable Ruby UI components live in `components/` and load with ordinary Ruby
        `require_relative`. Run `omarchy_ui bundle` to create a self-contained distribution.
      MARKDOWN
    end
  end
end
