# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "open3"
require "stringio"
require "tmpdir"
require_relative "../lib/omarchy_ui"
require_relative "../lib/omarchy_ui/cli"

class CLITest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_run_executes_the_requested_ruby_file_with_arguments
    Dir.mktmpdir do |directory|
      program = File.join(directory, "app.rb")
      File.write(program, "puts ARGV.join(':')\n")
      stdout, stderr, status = Open3.capture3(File.join(ROOT, "bin/omarchy_ui"), "run", program, "one", "two")
      assert status.success?, stderr
      assert_equal "one:two\n", stdout
    end
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
        refute File.exist?(File.join(destination, ".git"))
        refute Dir.children(File.join(home, ".config/omarchy/plugins")).any? { |name| name.include?("backup") }
        assert_includes output.string, "Pushed test.plugin"
      end
    end
  end

  def test_new_scaffolds_a_valid_runnable_framework_plugin
    Dir.mktmpdir do |directory|
      output = StringIO.new
      Dir.chdir(directory) do
        status = OmarchyUI::CLI.run(["new", "Weather Board", "--id", "test.weather-board"],
                                    out: output, err: StringIO.new)
        assert_equal 0, status
      end
      project = File.join(directory, "weather-board")
      manifest = JSON.parse(File.read(File.join(project, "manifest.json")))
      assert_equal "test.weather-board", manifest.fetch("id")
      %w[Service.qml ControlNode.qml Panel.qml BarWidget.qml main.rb].each do |file|
        assert File.file?(File.join(project, file)), "missing generated #{file}"
      end

      stdout, stderr, status = Open3.capture3(
        { "RUBYLIB" => File.join(ROOT, "lib") }, RbConfig.ruby, File.join(project, "main.rb")
      )
      assert status.success?, stderr
      assert_equal %w[ready render], stdout.lines.map { |line| JSON.parse(line).fetch("type") }
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
        test -f "$3/vendor/omarchy_ui/lib/omarchy_ui.rb" || exit 3
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
