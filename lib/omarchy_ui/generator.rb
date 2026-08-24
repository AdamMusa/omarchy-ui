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
      File.write(File.join(@path, "omarchy.rb"), omarchy_program)
      File.write(File.join(@path, "app.rb"), application_program)
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

        require_relative "app"

        #{constant_name}.run
      RUBY
    end

    def omarchy_program
      <<~RUBY
        # frozen_string_literal: true

        require "omarchy_ui"
        require_relative "app"

        OmarchyUI.run(#{constant_name})
      RUBY
    end

    def application_program
      <<~RUBY
        # frozen_string_literal: true

        require "zui"
        require_relative "components/welcome"

        module #{constant_name}
          def self.build
            Zui::Application.new(ui: UI) do
              app :main, title: "#{@name}", width: 760, height: 520 do
                welcome_card(
                  title: "Welcome to #{@name}",
                  message: "This app is powered by the Zui framework."
                )
              end
            end
          end

          def self.run = build.run
        end
      RUBY
    end

    def welcome_component
      <<~RUBY
        # frozen_string_literal: true

        module #{constant_name}
          module UI
            def welcome_card(title:, message:)
              container padding: 24, bordered: true do
                column spacing: 12 do
                  text title, style: :heading
                  text message, wrap: true
                end
              end
            end
          end
        end
      RUBY
    end

    def readme
      <<~MARKDOWN
        # #{@name}

        A pure Ruby Zui application that can use either the standard cross-platform host
        or the Omarchy UI adapter without changing its application code.

        ## Standard Zui host

        ```bash
        zui run main.rb
        ```

        ## Omarchy host

        ```bash
        omarchy_ui run omarchy.rb
        ```

        Reusable Ruby UI components live in `components/` and load with ordinary Ruby
        `require_relative`. Run `omarchy_ui bundle` to create a self-contained distribution.
      MARKDOWN
    end

    def constant_name
      @name.gsub(/[^a-zA-Z0-9]+/, " ").split.map(&:capitalize).join.then do |name|
        name.empty? || name.match?(/\A\d/) ? "OmarchyApplication" : name
      end
    end
  end
end
