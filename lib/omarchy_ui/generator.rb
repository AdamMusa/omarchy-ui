# frozen_string_literal: true

require "fileutils"

module OmarchyUI
  class Generator
    PROJECT_KINDS = %i[application plugin].freeze

    def initialize(path:, name: nil, kind: :application, plugin_id: nil, author: nil)
      @path = File.expand_path(path)
      @name = name || File.basename(@path).split(/[-_]/).map(&:capitalize).join(" ")
      @kind = kind.to_sym
      @plugin_id = plugin_id || "local.#{project_slug}"
      @author = author.to_s.strip.empty? ? "Omarchy UI Developer" : author.to_s.strip
      raise ArgumentError, "unsupported project kind: #{@kind}" unless PROJECT_KINDS.include?(@kind)
    end

    def create
      raise ArgumentError, "destination already exists: #{@path}" if File.exist?(@path)
      created = true
      FileUtils.mkdir_p(File.join(@path, "components"))
      File.write(File.join(@path, "main.rb"), main_program)
      File.write(File.join(@path, "app.rb"), application_program) unless plugin?
      File.write(File.join(@path, ProjectConfig::FILE_NAME), project_config)
      File.write(File.join(@path, "components", "welcome.rb"), welcome_component)
      File.write(File.join(@path, "README.md"), readme)
      File.write(File.join(@path, "LICENSE"), license)
      @path
    rescue StandardError
      FileUtils.remove_entry(@path) if created && File.directory?(@path)
      raise
    end

    private

    def main_program
      return plugin_program if plugin?

      <<~RUBY
        # frozen_string_literal: true

        require "omarchy_ui"
        require_relative "app"

        OmarchyUI.run(#{constant_name})
      RUBY
    end

    def plugin_program
      <<~RUBY
        # frozen_string_literal: true

        require "omarchy_ui"
        require_relative "components/welcome"

        OmarchyUI.plugin(ui: #{constant_name}::UI) do
          bar_widget do
            row spacing: 7 do
              text "#{@name}"
            end
            on_click { open_panel :#{surface_name} }
          end

          panel :#{surface_name} do
            scroll width: 560, height: 620 do
              welcome_card(
                title: "#{@name}",
                message: "Your Omarchy plugin is ready. Build the interface with Ruby and Zui components."
              )
            end
          end
        end
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
      return plugin_readme if plugin?

      <<~MARKDOWN
        # #{@name}

        A pure Ruby desktop application built with Zui and the Omarchy UI host.

        ## Run

        ```bash
        omarchy_ui run main.rb
        ```

        Reusable Ruby UI components live in `components/` and load with ordinary Ruby
        `require_relative`. Project identity and build settings live in `config.rb`.

        ## Build

        ```bash
        omarchy_ui bundle
        ```

        Omarchy UI generates the complete self-contained application package required by Omarchy.
      MARKDOWN
    end

    def plugin_readme
      <<~MARKDOWN
        # #{@name}

        A pure Ruby Omarchy plugin built with Omarchy UI and Zui.

        ## Validate

        ```bash
        omarchy_ui validate
        ```

        ## Install for development

        ```bash
        omarchy_ui push
        ```

        ## Build

        ```bash
        omarchy_ui bundle
        ```

        Write the plugin interface and behavior in Ruby under `main.rb` and `components/`.
        Public plugin identity and release metadata live in `config.rb`. Omarchy UI uses it to
        generate and validate the complete Omarchy-compatible plugin package.
      MARKDOWN
    end

    def project_config
      config = ProjectConfig.generate(
        name: @name,
        slug: project_slug,
        kind: @kind,
        author: @author,
        plugin_id: @plugin_id
      )
      config
    end

    def license
      <<~TEXT
        MIT License

        Copyright (c) #{Time.now.year} #{@author}

        Permission is hereby granted, free of charge, to any person obtaining a copy
        of this software and associated documentation files (the "Software"), to deal
        in the Software without restriction, including without limitation the rights
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        copies of the Software, and to permit persons to whom the Software is
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
        SOFTWARE.
      TEXT
    end

    def plugin?
      @kind == :plugin
    end

    def project_slug
      File.basename(@path).downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|\-\z/, "")
    end

    def surface_name
      project_slug.tr("-", "_")
    end

    def constant_name
      @name.gsub(/[^a-zA-Z0-9]+/, " ").split.map(&:capitalize).join.then do |name|
        name.empty? || name.match?(/\A\d/) ? "OmarchyApplication" : name
      end
    end
  end
end
