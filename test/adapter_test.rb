# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require_relative "../lib/omarchy_ui"

class AdapterTest < Minitest::Test
  module CounterUI
    def counter
      column do
        text { "Count: #{state.count}" }
        button("Increment") { state.count += 1 }
      end
    end
  end

  def test_omarchy_dsl_builds_with_zui_nodes
    application = OmarchyUI::Application.new(ui: CounterUI) do
      state :count, 0
      app(:main, title: "Adapter") { counter }
    end

    assert_instance_of Zui::Application, application
    assert_equal "container", application.surfaces.fetch("main").type
    assert_equal "column", application.surfaces.fetch("main").children.first.type
    refute_includes OmarchyUI::Builder.instance_methods, :counter
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

  def test_run_accepts_a_shared_zui_application_module
    application = OmarchyUI::Application.new do
      app(:main) { text "Shared" }
    end
    application.define_singleton_method(:run) { :ran_through_omarchy }
    domain = Module.new
    domain.define_singleton_method(:build) { application }

    assert_equal :ran_through_omarchy, OmarchyUI.run(domain)
    assert_equal :ran_through_omarchy, OmarchyUI.run(application)
  end

  def test_run_rejects_objects_that_are_not_zui_applications
    invalid_domain = Module.new
    invalid_domain.define_singleton_method(:build) { Object.new }

    assert_raises(ArgumentError) { OmarchyUI.run(Object.new) }
    assert_raises(ArgumentError) { OmarchyUI.run(invalid_domain) }
  end
end
