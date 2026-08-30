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

  def test_push_preserves_a_verified_precompiled_package
    Dir.mktmpdir do |directory|
      home = File.join(directory, "home")
      source = File.join(directory, "source")
      tools = File.join(directory, "bin")
      module_path = "OmarchyUI/Bundles/Btest"
      module_directory = File.join(source, module_path)
      FileUtils.mkdir_p([home, source, tools, module_directory])
      File.write(File.join(source, "manifest.json"), JSON.generate("id" => "test.compiled"))
      File.write(File.join(source, "main.rb"), "# compiled plugin\n")
      OmarchyUI::QmlCompiler::ENTRY_TYPES.each_key do |entry|
        File.write(File.join(source, entry), "import QtQuick\nItem {}\n")
      end
      File.write(File.join(module_directory, "qmldir"), "module OmarchyUI.Bundles.Btest\n")
      artifacts = %w[libbundle.so libbundleplugin.so].map do |name|
        path = File.join(module_path, name)
        absolute = File.join(source, path)
        File.binwrite(absolute, "compiled artifact: #{name}\n")
        {
          "path" => path,
          "sha256" => Digest::SHA256.file(absolute).hexdigest,
          "bytes" => File.size(absolute)
        }
      end
      report = {
        "format" => "qt-aot-qml-module",
        "format_version" => OmarchyUI::QmlCompiler::FORMAT_VERSION,
        "module_path" => module_path,
        "artifacts" => artifacts
      }
      File.write(File.join(source, OmarchyUI::QmlCompiler::REPORT), JSON.generate(report))
      File.write(File.join(source, OmarchyUI::QmlCompiler::CHECKSUM), "package checksum marker\n")

      omarchy = File.join(tools, "omarchy")
      File.write(omarchy, <<~SH)
        #!/bin/sh
        test -f "$3/#{OmarchyUI::QmlCompiler::REPORT}" || exit 2
        test -f "$3/#{module_path}/libbundle.so" || exit 3
        test ! -e "$3/ControlNode.qml" || exit 4
      SH
      FileUtils.chmod(0o755, omarchy)

      with_environment("HOME" => home, "PATH" => "#{tools}:#{ENV.fetch('PATH')}") do
        status = OmarchyUI::CLI.run(
          ["push", "--no-enable", "--no-restart", source],
          out: StringIO.new,
          err: StringIO.new
        )
        destination = File.join(home, ".config/omarchy/plugins/test.compiled")
        assert_equal 0, status
        assert_equal report, JSON.parse(File.read(File.join(destination, OmarchyUI::QmlCompiler::REPORT)))
        assert File.file?(File.join(destination, module_path, "libbundleplugin.so"))
        refute File.exist?(File.join(destination, "ControlNode.qml"))
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
      assert_equal %w[LICENSE README.md app.rb components config.rb main.rb], Dir.children(project).sort
      assert_equal ["welcome.rb"], Dir.children(File.join(project, "components"))
      refute File.exist?(File.join(project, "manifest.json"))
      config = OmarchyUI::ProjectConfig.load(project)
      assert config.application?
      assert_equal "Weather Board", config.name
      assert_equal "weather-board", config.slug
      assert_equal "main.rb", config.entrypoint
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
        assert_equal %w[LICENSE README.md components config.rb main.rb], Dir.children(project).sort
        refute File.exist?(File.join(project, "manifest.json"))
        config = OmarchyUI::ProjectConfig.load(project)
        assert config.plugin?
        assert_equal "system-status", config.slug
        assert_equal "main.rb", config.entrypoint
        assert_equal "0.1.0", config.to_h.fetch(:version)
        manifest = config.manifest
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

        config_path = File.join(project, "config.rb")
        configured = File.read(config_path).sub('slug "system-status"', 'slug "system-monitor"')
        File.write(config_path, configured)
        status = OmarchyUI::CLI.run(["bundle", project], out: output, err: StringIO.new)
        bundle = File.join(project, "dist", "system-monitor")
        assert_equal 0, status
        assert File.file?(File.join(bundle, "manifest.json"))
        refute File.exist?(File.join(bundle, "config.rb"))
        bundled_manifest = JSON.parse(File.read(File.join(bundle, "manifest.json")))
        assert_equal "local.system-status", bundled_manifest.fetch("id")
        assert_equal "System Status", bundled_manifest.fetch("name")
        assert_equal "0.1.0", bundled_manifest.fetch("version")
        assert File.file?(File.join(bundle, "Service.qml"))
        assert File.file?(File.join(bundle, "Panel.qml"))
        assert File.file?(File.join(bundle, "BarWidget.qml"))
        assert File.file?(File.join(bundle, "App.qml"))
        assert_equal %w[App.qml BarWidget.qml Panel.qml Service.qml],
          Dir.glob(File.join(bundle, "**", "*.qml")).map { |path| path.delete_prefix("#{bundle}/") }.sort
        refute File.exist?(File.join(bundle, "ControlNode.qml"))
        refute File.exist?(File.join(bundle, "Components"))
        refute File.exist?(File.join(bundle, "Controls"))
        refute File.exist?(File.join(bundle, "Theme"))
        refute File.exist?(File.join(bundle, "Fonts"))
        assert File.executable?(File.join(bundle, "omarchy-ui-runtime"))
        report = JSON.parse(File.read(File.join(bundle, OmarchyUI::Runtime::TREE_SHAKE_REPORT)))
        assert_includes report.fetch("components"), "text"
        assert_operator report.fetch("saved_bytes"), :>, 0
        compiled = JSON.parse(File.read(File.join(bundle, OmarchyUI::QmlCompiler::REPORT)))
        assert_equal "qt-aot-qml-module", compiled.fetch("format")
        assert_equal OmarchyUI::QmlCompiler::FORMAT_VERSION, compiled.fetch("format_version")
        assert_match(/\A6\./, compiled.fetch("qt_version"))
        assert_equal %w[App.qml BarWidget.qml Panel.qml Service.qml], compiled.fetch("entry_shims").sort
        assert_operator compiled.fetch("source_files"), :>, 4
        module_path = File.join(bundle, compiled.fetch("module_path"))
        assert File.file?(File.join(module_path, "qmldir"))
        assert_equal 2, compiled.fetch("artifacts").length
        compiled.fetch("artifacts").each do |artifact|
          artifact_path = File.join(bundle, artifact.fetch("path"))
          assert File.file?(artifact_path)
          assert_equal artifact.fetch("sha256"), Digest::SHA256.file(artifact_path).hexdigest
          assert_equal artifact.fetch("bytes"), File.size(artifact_path)
        end
        checksum = File.read(File.join(bundle, OmarchyUI::QmlCompiler::CHECKSUM))
        compiled.fetch("artifacts").each { |artifact| assert_includes checksum, artifact.fetch("sha256") }
        provenance = File.read(File.join(bundle, OmarchyUI::QmlCompiler::PROVENANCE))
        assert_includes provenance, compiled.fetch("module_uri")
        assert_includes provenance, "sha256sum --check #{OmarchyUI::QmlCompiler::CHECKSUM}"
        OmarchyUI::QmlCompiler::ENTRY_TYPES.each do |entry, type|
          shim = File.read(File.join(bundle, entry))
          assert_operator shim.bytesize, :<, 160
          expected_import = type == "App" ? compiled.fetch("module_uri") : %Q("#{compiled.fetch('module_path')}")
          assert_includes shim, "import #{expected_import} as Compiled"
          assert_includes shim, "Compiled.#{type} {}"
        end
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
      File.write(File.join(source, "config.rb"), OmarchyUI::ProjectConfig.generate(
        name: "Validation Test",
        slug: "validation-test",
        kind: :plugin,
        author: "Test Developer",
        plugin_id: "test.validate"
      ))
      File.write(File.join(source, "main.rb"), "require \"omarchy_ui\"\n")
      omarchy = File.join(tools, "omarchy")
      File.write(omarchy, <<~SH)
        #!/bin/sh
        test -f "$3/Service.qml" || exit 2
        test ! -e "$3/vendor" || exit 3
        test -f "$3/manifest.json" || exit 4
        test ! -e "$3/config.rb" || exit 5
        cp "$3/Service.qml" #{inspected}
      SH
      FileUtils.chmod(0o755, omarchy)

      with_environment("PATH" => "#{tools}:#{ENV.fetch('PATH')}") do
        status = OmarchyUI::CLI.run(["validate", source], out: StringIO.new, err: StringIO.new)
        assert_equal 0, status
        assert File.file?(inspected)
      end
      refute File.exist?(File.join(source, "Service.qml")), "validation must not mutate source"
      refute File.exist?(File.join(source, "manifest.json")), "manifest must only be generated while staging"
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
      assert_includes launcher, "QML2_IMPORT_PATH"
      assert_includes launcher, "QML_IMPORT_PATH"
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
