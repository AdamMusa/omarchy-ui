# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require_relative "../lib/omarchy_ui"

class AdapterTest < Minitest::Test
  def test_omarchy_dsl_builds_with_zui_nodes
    application = OmarchyUI::Application.new do
      state :count, 0
      app :main, title: "Adapter" do
        column do
          text { "Count: #{state.count}" }
          button("Increment") { state.count += 1 }
        end
      end
    end

    assert_instance_of Zui::Application, application
    assert_equal "container", application.surfaces.fetch("main").type
    assert_equal "column", application.surfaces.fetch("main").children.first.type
  end

  def test_source_bundle_removes_both_framework_entrypoints
    Dir.mktmpdir do |directory|
      entrypoint = File.join(directory, "main.rb")
      File.write(entrypoint, "require \"omarchy_ui\"\nrequire \"zui\"\nputs \"plugin\"\n")

      source = OmarchyUI::SourceBundle.new(entrypoint).call

      refute_includes source, 'require "omarchy_ui"'
      refute_includes source, 'require "zui"'
      assert_includes source, 'puts "plugin"'
    end
  end
end
