# frozen_string_literal: true

require "json"
require "minitest/autorun"

class ManifestTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  MANIFEST = JSON.parse(File.read(File.join(ROOT, "manifest.json")))

  def test_manifest_matches_omarchy_schema_one
    assert_equal 1, MANIFEST.fetch("schemaVersion")
    refute MANIFEST.fetch("id").start_with?("omarchy.")
    assert_equal %w[service bar-widget panel].sort, MANIFEST.fetch("kinds").sort

    required = {
      "service" => "service",
      "bar-widget" => "barWidget",
      "panel" => "panel"
    }
    required.each do |kind, key|
      next unless MANIFEST.fetch("kinds").include?(kind)

      entry = MANIFEST.fetch("entryPoints").fetch(key)
      refute entry.start_with?("/")
      refute entry.include?("..")
      assert File.file?(File.join(ROOT, entry)), "missing entry point #{entry}"
    end
  end

  def test_plugin_tree_contains_no_symlinks
    links = Dir.glob(File.join(ROOT, "**", "*"), File::FNM_DOTMATCH).select do |path|
      !path.include?("/.git/") && File.symlink?(path)
    end
    assert_empty links
  end
end

