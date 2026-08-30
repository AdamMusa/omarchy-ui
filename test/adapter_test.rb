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

  def test_component_catalog_omits_only_identity_mappings_for_quickshell
    button = OmarchyUI::DEFAULT_COMPONENTS.fetch(:button).to_h

    refute button.key?("property_map")
    refute button.key?("event_map")
    assert button.fetch("properties").include?("text")

    registry = Zui::ComponentRegistry.new
    registry.register(:mapped, qml: "Mapped.qml", properties: [:value], events: [:change],
                      property_map: { value: :model_data }, event_map: { change: :changed })
    mapped = registry.fetch(:mapped).to_h

    assert_equal({ "value" => "model_data" }, mapped.fetch("property_map"))
    assert_equal({ "change" => "changed" }, mapped.fetch("event_map"))
    assert_operator JSON.generate(OmarchyUI::DEFAULT_COMPONENTS.protocol_schema).bytesize, :<, 131_072
    chunks = OmarchyUI.component_protocol_chunks(OmarchyUI::DEFAULT_COMPONENTS)
    assert_operator chunks.length, :>, 1
    chunks.each_with_index do |components, index|
      envelope = { "v" => 1, "type" => "component_catalog", "reset" => index.zero?, "components" => components }
      assert_operator JSON.generate(envelope).bytesize, :<, 65_536
    end
    assert_equal OmarchyUI::DEFAULT_COMPONENTS.protocol_schema.keys.sort,
                 chunks.flat_map(&:keys).sort
  end
end
