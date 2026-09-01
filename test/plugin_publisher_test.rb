# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "minitest/mock"
require "stringio"
require "tmpdir"
require_relative "../lib/omarchy_ui"

class PluginPublisherTest < Minitest::Test
  def test_rejects_invalid_marketplace_metadata_before_external_commands
    publisher = build_publisher(category: "Utilities", tags: %w[system])
    error = assert_raises(ArgumentError) { publisher.send(:validate_options!) }
    assert_includes error.message, "publish category"

    publisher = build_publisher(category: "System", tags: %w[system unknown])
    error = assert_raises(ArgumentError) { publisher.send(:validate_options!) }
    assert_includes error.message, "one to three allowed tags"
  end

  def test_submission_body_matches_the_marketplace_cli_contract
    publisher = build_publisher(category: "System", tags: %w[system quickshell])
    body = publisher.send(:submission_body, commit: "a" * 40)

    assert_equal [
      "Repository URL", "Category", "Tags", "Suggest a missing tag", "Maintainer notes", "Submission checklist"
    ], body.scan(/^### (.+)$/).flatten
    assert_includes body, "https://github.com/Example/test-plugin"
    assert_includes body, "system, quickshell"
    assert_equal 5, body.scan(/^- \[x\] /).length
    assert_includes body, "`#{'a' * 40}`"
  end

  def test_refuses_to_replace_the_source_repository
    Dir.mktmpdir do |directory|
      package = File.join(directory, "package")
      source = File.join(directory, "source")
      FileUtils.mkdir_p([package, source])
      File.write(File.join(package, "README.md"), <<~MARKDOWN)
        ## Install
        `omarchy plugin add https://github.com/Example/test-plugin.git --enable`
      MARKDOWN
      system("git", "-C", source, "init", "--quiet")
      system("git", "-C", source, "remote", "add", "origin", "git@github.com:Example/test-plugin.git")
      manifest = {"name" => "Test Plugin", "version" => "0.1.0", "id" => "example.test"}
      publisher = build_publisher(package:, source:)

      error = OmarchyUI::PluginPackage.stub(:validate!, manifest) do
        assert_raises(ArgumentError) { publisher.publish! }
      end
      assert_includes error.message, "separate distribution repository"
    end
  end

  def test_publishes_package_and_creates_marketplace_submission
    Dir.mktmpdir do |directory|
      remote = File.join(directory, "remote.git")
      seed = File.join(directory, "seed")
      package = File.join(directory, "package")
      source = File.join(directory, "source")
      tools = File.join(directory, "bin")
      FileUtils.mkdir_p([package, source, tools])
      system("git", "init", "--bare", "--initial-branch=main", remote, out: File::NULL)
      system("git", "init", "--initial-branch=main", seed, out: File::NULL)
      File.write(File.join(seed, "manifest.json"), JSON.generate("id" => "example.test"))
      system("git", "-C", seed, "add", "manifest.json")

      environment = git_environment.merge(
        "PATH" => "#{tools}:#{ENV.fetch('PATH')}",
        "OMARCHY_UI_TEST_REMOTE" => remote
      )
      with_environment(environment) do
        system("git", "-C", seed, "commit", "--quiet", "-m", "Seed")
        system("git", "-C", seed, "remote", "add", "origin", remote)
        system("git", "-C", seed, "push", "--quiet", "-u", "origin", "main")

        File.write(File.join(package, "manifest.json"), JSON.generate("id" => "example.test"))
        File.write(File.join(package, "main.rb"), "puts \"published\"\n")
        File.write(File.join(package, "README.md"),
                   "omarchy plugin add https://github.com/Example/test-plugin.git --enable\n")
        File.write(File.join(package, "LICENSE"), "MIT\n")
        gh = File.join(tools, "gh")
        File.write(gh, <<~SH)
          #!/bin/sh
          if [ "$1 $2" = "auth status" ]; then exit 0; fi
          if [ "$1 $2" = "repo view" ]; then printf 'Example/test-plugin\tPUBLIC\n'; exit 0; fi
          if [ "$1 $2" = "repo clone" ]; then exec git clone "$OMARCHY_UI_TEST_REMOTE" "$4" --quiet; fi
          if [ "$1 $2" = "issue list" ]; then printf '[]\n'; exit 0; fi
          if [ "$1 $2" = "issue create" ]; then printf 'https://github.com/omacom/omarchy-plugin-marketplace/issues/1\n'; exit 0; fi
          exit 9
        SH
        FileUtils.chmod(0o755, gh)

        manifest = {"name" => "Test Plugin", "version" => "0.1.0", "id" => "example.test"}
        output = StringIO.new
        publisher = OmarchyUI::PluginPublisher.new(
          package:,
          source:,
          repository: "Example/test-plugin",
          category: "System",
          tags: %w[system quickshell],
          submit: true,
          out: output
        )
        commit = OmarchyUI::PluginPackage.stub(:validate!, manifest) { publisher.publish! }

        assert_match(/\A[0-9a-f]{40}\z/, commit)
        assert_includes output.string, "Marketplace issue preview"
        assert_includes output.string, "issues/1"
        checkout = File.join(directory, "published")
        system("git", "clone", "--quiet", remote, checkout)
        assert_equal %w[LICENSE README.md main.rb manifest.json],
          Dir.children(checkout).reject { |entry| entry == ".git" }.sort
        assert_equal "puts \"published\"\n", File.read(File.join(checkout, "main.rb"))
      end
    end
  end

  private

  def build_publisher(package: ".", source: ".", category: "System", tags: %w[system])
    OmarchyUI::PluginPublisher.new(
      package:,
      source:,
      repository: "Example/test-plugin",
      category:,
      tags:,
      out: StringIO.new
    )
  end

  def git_environment
    {
      "GIT_AUTHOR_NAME" => "Test Developer",
      "GIT_AUTHOR_EMAIL" => "test@example.invalid",
      "GIT_COMMITTER_NAME" => "Test Developer",
      "GIT_COMMITTER_EMAIL" => "test@example.invalid"
    }
  end

  def with_environment(values)
    previous = values.to_h { |key, _value| [key, ENV[key]] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
