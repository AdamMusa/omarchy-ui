# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "minitest/mock"
require "open3"
require "stringio"
require "tmpdir"
require_relative "../lib/omarchy_ui"
require_relative "../lib/omarchy_ui/cli"

class CLITest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_interrupt_exits_cleanly_without_a_backtrace
    error = StringIO.new
    cli = OmarchyUI::CLI.new(out: StringIO.new, err: error)

    status = cli.stub(:run_file, ->(_arguments) { raise Interrupt }) do
      cli.run(["run", "main.rb"])
    end

    assert_equal 130, status
    assert_empty error.string
  end

  def test_run_opens_the_requested_file_through_the_omarchy_host
    requested = nil
    cli = OmarchyUI::CLI.new(out: StringIO.new, err: StringIO.new)

    status = cli.stub(:run_file, ->(arguments) { requested = arguments; 0 }) do
      cli.run(["run", "main.rb"])
    end

    assert_equal 0, status
    assert_equal ["main.rb"], requested
    assert_equal 64, cli.run(["launch", "main.rb"])
  end

  def test_push_stages_validates_and_installs_without_copying_git_metadata
    Dir.mktmpdir do |directory|
      home = File.join(directory, "home")
      source = File.join(directory, "source")
      tools = File.join(directory, "bin")
      FileUtils.mkdir_p([home, source, tools, File.join(source, ".git")])
      File.write(File.join(source, "manifest.json"), JSON.generate("id" => "test.plugin"))
      File.write(File.join(source, "main.rb"), "# plugin\n")
      File.write(File.join(source, ".git", "config"), "secret metadata\n")
      omarchy = File.join(tools, "omarchy")
      File.write(omarchy, "#!/bin/sh\nexit 0\n")
      FileUtils.chmod(0o755, omarchy)

      with_environment("HOME" => home, "PATH" => "#{tools}:#{ENV.fetch('PATH')}") do
        output = StringIO.new
        status = OmarchyUI::CLI.run(["push", "--no-enable", "--no-restart", source], out: output, err: StringIO.new)
        destination = File.join(home, ".config/omarchy/plugins/test.plugin")
        assert_equal 0, status
        assert File.file?(File.join(destination, "main.rb"))
        assert File.file?(File.join(destination, "Service.qml"))
        assert File.file?(File.join(destination, "ControlNode.qml"))
        assert File.file?(File.join(destination, "Components", "Builtins", "Container.qml"))
        assert File.file?(File.join(destination, OmarchyUI::Runtime::TREE_SHAKE_REPORT))
        refute File.exist?(File.join(destination, "Desktop.qml"))
        assert File.executable?(File.join(destination, "omarchy-ui-runtime"))
        refute File.exist?(File.join(destination, "vendor")), "plugins use the shared native runtime"
        refute File.exist?(File.join(destination, ".git"))
        refute Dir.children(File.join(home, ".config/omarchy/plugins")).any? { |name| name.include?("backup") }
        assert_includes output.string, "Pushed test.plugin"
      end
    end
  end

  def test_new_scaffolds_only_application_owned_files
    Dir.mktmpdir do |directory|
      output = StringIO.new
      Dir.chdir(directory) do
        status = OmarchyUI::CLI.run(["new", "Weather Board"],
                                    out: output, err: StringIO.new)
        assert_equal 0, status
      end
      project = File.join(directory, "weather-board")
      assert_equal %w[LICENSE README.md app.rb components main.rb], Dir.children(project).sort
      assert_equal ["welcome.rb"], Dir.children(File.join(project, "components"))
      refute File.exist?(File.join(project, "manifest.json"))
      application = File.read(File.join(project, "app.rb"))
      entrypoint = File.read(File.join(project, "main.rb"))
      assert_includes application, "welcome_card("
      assert_includes application, 'require "zui"'
      assert_includes application, 'require_relative "components/welcome"'
      assert_includes application, "module WeatherBoard"
      assert_includes application, "Zui::Application.new(ui: UI)"
      refute_includes application, "OmarchyUI"
      assert_includes entrypoint, 'require "omarchy_ui"'
      assert_includes entrypoint, "OmarchyUI.run(WeatherBoard)"
      refute_includes application, "eval("
      refute_includes File.read(File.join(project, "components", "welcome.rb")), "Builder.include"
      refute Dir.glob(File.join(project, "**", "*.qml")).any?
      assert_includes File.read(File.join(project, "README.md")), "omarchy_ui run main.rb"

      stdout, stderr, status = Open3.capture3(
        RbConfig.ruby, "-I", File.join(ROOT, "lib"), File.join(project, "main.rb")
      )
      assert status.success?, stderr
      message_types = stdout.lines.map { |line| JSON.parse(line).fetch("type") }
      assert_equal "ready", message_types.first
      assert_equal "render", message_types.last
      assert_includes message_types, "component_catalog"
    end
  end

  def test_new_plugin_generates_and_bundles_a_complete_omarchy_plugin
    Dir.mktmpdir do |directory|
      output = StringIO.new
      tools = File.join(directory, "bin")
      FileUtils.mkdir_p(tools)
      omarchy = File.join(tools, "omarchy")
      File.write(omarchy, "#!/bin/sh\nexit 0\n")
      FileUtils.chmod(0o755, omarchy)

      with_environment(
        "OMARCHY_UI_AUTHOR" => "Example Developer",
        "PATH" => "#{tools}:#{ENV.fetch('PATH')}"
      ) do
        Dir.chdir(directory) do
          status = OmarchyUI::CLI.run(["new", "--plugin", "System Status"],
                                      out: output, err: StringIO.new)
          assert_equal 0, status
        end

        project = File.join(directory, "system-status")
        assert_equal %w[LICENSE README.md components main.rb manifest.json], Dir.children(project).sort
        manifest = JSON.parse(File.read(File.join(project, "manifest.json")))
        assert_equal 1, manifest.fetch("schemaVersion")
        assert_equal "local.system-status", manifest.fetch("id")
        assert_equal "System Status", manifest.fetch("name")
        assert_equal "Example Developer", manifest.fetch("author")
        assert_equal ["service", "bar-widget", "panel"], manifest.fetch("kinds")
        assert_equal({
          "service" => "Service.qml",
          "barWidget" => "BarWidget.qml",
          "panel" => "Panel.qml"
        }, manifest.fetch("entryPoints"))
        refute File.exist?(File.join(project, "app.rb"))
        refute Dir.glob(File.join(project, "**", "*.qml")).any?

        entrypoint = File.read(File.join(project, "main.rb"))
        assert_includes entrypoint, "OmarchyUI.plugin(ui: SystemStatus::UI)"
        assert_includes entrypoint, "bar_widget do"
        assert_includes entrypoint, "panel :system_status do"
        assert_includes File.read(File.join(project, "README.md")),
                        "complete Omarchy-compatible plugin package"

        status = OmarchyUI::CLI.run(["bundle", project], out: output, err: StringIO.new)
        bundle = File.join(project, "dist", "system-status")
        assert_equal 0, status
        assert File.file?(File.join(bundle, "manifest.json"))
        assert File.file?(File.join(bundle, "Service.qml"))
        assert File.file?(File.join(bundle, "Panel.qml"))
        assert File.file?(File.join(bundle, "BarWidget.qml"))
        assert File.executable?(File.join(bundle, "omarchy-ui-runtime"))
        report = JSON.parse(File.read(File.join(bundle, OmarchyUI::Runtime::TREE_SHAKE_REPORT)))
        assert_includes report.fetch("components"), "text"
        assert_operator report.fetch("saved_bytes"), :>, 0
        assert_includes output.string, "Created Omarchy-compliant plugin"
        assert_includes output.string, "Bundled plugin"
      end
    end
  end

  def test_validate_checks_the_complete_staged_ruby_plugin
    Dir.mktmpdir do |directory|
      source = File.join(directory, "source")
      tools = File.join(directory, "bin")
      inspected = File.join(directory, "inspected")
      FileUtils.mkdir_p([source, tools])
      File.write(File.join(source, "manifest.json"), JSON.generate("id" => "test.validate"))
      File.write(File.join(source, "main.rb"), "require \"omarchy_ui\"\n")
      omarchy = File.join(tools, "omarchy")
      File.write(omarchy, <<~SH)
        #!/bin/sh
        test -f "$3/Service.qml" || exit 2
        test ! -e "$3/vendor" || exit 3
        cp "$3/Service.qml" #{inspected}
      SH
      FileUtils.chmod(0o755, omarchy)

      with_environment("PATH" => "#{tools}:#{ENV.fetch('PATH')}") do
        status = OmarchyUI::CLI.run(["validate", source], out: StringIO.new, err: StringIO.new)
        assert_equal 0, status
        assert File.file?(inspected)
      end
      refute File.exist?(File.join(source, "Service.qml")), "validation must not mutate source"
    end
  end

  def test_bundle_embeds_runtime_bridge_and_direct_launcher
    Dir.mktmpdir do |directory|
      source = File.join(directory, "demo")
      FileUtils.mkdir_p(source)
      File.write(File.join(source, "main.rb"), "# app\n")
      output = StringIO.new

      status = OmarchyUI::CLI.run(["bundle", source], out: output, err: StringIO.new)
      bundle = File.join(source, "dist", "demo")

      assert_equal 0, status
      assert File.executable?(File.join(bundle, "omarchy-ui-runtime"))
      assert File.executable?(File.join(bundle, "run"))
      assert File.file?(File.join(bundle, "App.qml"))
      assert File.symlink?(File.join(bundle, "Commons"))
      launcher = File.read(File.join(bundle, "run"))
      assert_includes launcher, "exec quickshell"
      assert_includes launcher, "qt.qpa.services.warning=false"
    end
  end

  def test_bundle_resolves_normal_ruby_require_relative_calls
    Dir.mktmpdir do |directory|
      source = File.join(directory, "demo")
      FileUtils.mkdir_p(File.join(source, "components"))
      File.write(File.join(source, "main.rb"), "require_relative \"components/card\"\nputs Card\n")
      File.write(File.join(source, "components", "card.rb"), "Card = \"welcome\"\n")

      status = OmarchyUI::CLI.run(["bundle", source], out: StringIO.new, err: StringIO.new)
      bundled_main = File.read(File.join(source, "dist", "demo", "main.rb"))

      assert_equal 0, status
      assert_includes bundled_main, 'Card = "welcome"'
      refute_includes bundled_main, "require_relative"
      stdout, stderr, process = Open3.capture3(RbConfig.ruby, File.join(source, "dist", "demo", "main.rb"))
      assert process.success?, stderr
      assert_equal "welcome\n", stdout
    end
  end

  def test_bundle_omits_framework_require_already_embedded_in_runtime
    Dir.mktmpdir do |directory|
      entrypoint = File.join(directory, "main.rb")
      File.write(entrypoint, "require \"omarchy_ui\"\nputs \"app\"\n")

      bundled = OmarchyUI::SourceBundle.new(entrypoint).call

      refute_includes bundled, 'require "omarchy_ui"'
      assert_includes bundled, 'puts "app"'
    end
  end

  def test_bundle_builds_plugin_from_application_owned_files
    Dir.mktmpdir do |directory|
      source = File.join(directory, "sample-plugin")
      tools = File.join(directory, "bin")
      FileUtils.mkdir_p([source, tools])
      File.write(File.join(source, "main.rb"), "# app\n")
      File.write(File.join(source, "manifest.json"), JSON.generate("id" => "test.sample"))
      File.write(File.join(source, "ControlNode.qml"), "stale generated file\n")
      omarchy = File.join(tools, "omarchy")
      File.write(omarchy, "#!/bin/sh\ntest -x \"$3/omarchy-ui-runtime\"\n")
      FileUtils.chmod(0o755, omarchy)

      with_environment("PATH" => "#{tools}:#{ENV.fetch('PATH')}") do
        status = OmarchyUI::CLI.run(["bundle", source], out: StringIO.new, err: StringIO.new)
        bundle = File.join(source, "dist", "sample-plugin")
        assert_equal 0, status
        assert File.executable?(File.join(bundle, "omarchy-ui-runtime"))
        assert File.file?(File.join(bundle, "ControlNode.qml"))
        assert File.file?(File.join(bundle, "Components", "Builtins", "Container.qml"))
        assert File.file?(File.join(bundle, OmarchyUI::Runtime::TREE_SHAKE_REPORT))
        refute File.exist?(File.join(bundle, "Desktop.qml"))
        refute File.exist?(File.join(bundle, "run"))
        refute File.exist?(File.join(bundle, "Commons"))
      end
    end
  end

  private

  def with_environment(values)
    previous = {}
    values.each_key { |key| previous[key] = ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
