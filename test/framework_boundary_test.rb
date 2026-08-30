# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require_relative "../lib/omarchy_ui"

class FrameworkBoundaryTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  ADAPTER_QML = %w[App.qml BarWidget.qml Panel.qml Service.qml ZuiRenderer.qml].freeze
  REMOVED_CORE_FILES = %w[
    animation application builder command component_registry components node protocol
    scheduler source_bundle state_store value
  ].map { |name| File.join(ROOT, "lib", "omarchy_ui", "#{name}.rb") }.freeze

  def test_gem_is_an_explicit_zui_adapter
    specification = Gem::Specification.load(File.join(ROOT, "omarchy-ui.gemspec"))
    dependency = specification.dependencies.find { |candidate| candidate.name == "zui" }

    refute_nil dependency
    assert_equal Gem::Requirement.new("= 0.0.10"), dependency.requirement
    assert dependency.requirement.satisfied_by?(Gem::Version.new(Zui::VERSION))
    refute dependency.requirement.satisfied_by?(Gem::Version.new("0.0.9"))
    refute dependency.requirement.satisfied_by?(Gem::Version.new("0.0.11"))
    assert_empty specification.files.grep(%r{\AComponents/})
    assert_empty specification.files.grep(%r{\Alib/omarchy_ui/(?:animation|application|builder|node)\.rb\z})
  end

  def test_runtime_build_inputs_and_remote_attestation_are_pinned
    inputs = File.read(File.join(ROOT, "runtime", "inputs.env"))
    config = File.read(File.join(ROOT, "runtime", "build_config.rb"))
    workflow = File.read(File.join(ROOT, ".github", "workflows", "runtime-release.yml"))

    assert_match(/^ZUI_REVISION=[0-9a-f]{40}$/, inputs)
    %w[MRUBY_JSON_REVISION MRUBY_REGEXP_PCRE_REVISION MRUBY_ENV_REVISION MRUBY_PROCESS_REVISION].each do |name|
      assert_match(/^#{name}=[0-9a-f]{40}$/, inputs)
      assert_includes config, %(ENV.fetch("#{name}"))
    end
    assert_includes workflow, "Build twice and require byte-identical outputs"
    assert_includes workflow, "cmp \"$RUNNER_TEMP/omarchy-ui-runtime.first\" build/runtime/omarchy-ui-runtime"
    assert_includes workflow, "runtime_http_audit_check.rb"
    assert_includes workflow, "actions/attest@1e69f48acb82d1966a394da916b4c1698aa569d6"
    assert_includes workflow, "subject-path: dist/omarchy-ui-runtime"
    assert_includes File.read(File.join(ROOT, "scripts", "build-mruby-runtime.sh")),
                    "strip --remove-section=.note.gnu.build-id"
  end

  def test_omarchy_bridge_accepts_bounded_property_patch_batches
    service = File.read(File.join(ROOT, "Service.qml"))

    assert_includes service, 'message.op === "batch"'
    assert_includes service, 'message.type === "component_catalog"'
    assert_includes service, "installComponentCatalog(message)"
    assert_includes service, "message.patches.length > maxCollectionItems"
    assert_includes service, 'batchPatch.op !== "set"'
    assert_includes service, "if (!applyPatch({"
    assert_match(/nodeIndex = nextIndex\n\s+revision \+= 1\n\s+return true/, service)
  end

  def test_panel_uses_the_plugin_identity_as_its_layer_namespace
    panel = File.read(File.join(ROOT, "Panel.qml"))

    assert_includes panel, "readonly property string layerNamespace: manifest && manifest.id"
    assert_includes panel, "WlrLayershell.namespace: root.layerNamespace"
    refute_includes panel, 'WlrLayershell.namespace: "omarchy-ruby-ui-poc"'
  end

  def test_ruby_api_delegates_to_the_same_zui_core_objects
    assert_same Zui::Application, OmarchyUI::Application
    assert_same Zui::Builder, OmarchyUI::Builder
    assert_same Zui::StateStore, OmarchyUI::StateStore
    assert_same Zui::COMPONENTS, OmarchyUI::COMPONENTS
    assert_operator OmarchyUI::SourceBundle, :<, Zui::SourceBundle
    assert_equal Zui::Application.instance_method(:initialize).parameters,
                 OmarchyUI::Application.instance_method(:initialize).parameters
  end

  def test_repository_contains_only_the_omarchy_adapter_surface
    assert_empty REMOVED_CORE_FILES.select { |path| File.exist?(path) }
    refute Dir.exist?(File.join(ROOT, "Components"))
    refute File.exist?(File.join(ROOT, "ControlNode.qml"))
    assert_equal ADAPTER_QML, Dir[File.join(ROOT, "*.qml")].map { |path| File.basename(path) }.sort
  end

  def test_adapter_runtime_installs_only_the_omarchy_host
    Dir.mktmpdir do |directory|
      OmarchyUI::Runtime.install_package(directory)

      assert_equal File.read(File.join(ROOT, "Service.qml")), File.read(File.join(directory, "Service.qml"))
      assert_equal File.read(File.join(ROOT, "ZuiRenderer.qml")), File.read(File.join(directory, "ZuiRenderer.qml"))
      assert_equal File.read(File.join(ROOT, "vendor", "runtime", "x86_64-linux", "runtime-provenance.json")),
                   File.read(File.join(directory, "runtime-provenance.json"))
      OmarchyUI::Runtime::ZUI_GENERATED_ENTRIES.each do |entry|
        refute File.exist?(File.join(directory, entry)), "#{entry} must be resolved from the Zui gem"
      end
    end
  end

  def test_adapter_locates_the_exact_zui_gem_at_runtime
    service = File.read(File.join(ROOT, "Service.qml"))
    renderer = File.read(File.join(ROOT, "ZuiRenderer.qml"))

    assert_includes service, 'gem "zui", "= '
    assert_includes service, "Zui::FRAMEWORK_ROOT"
    assert_includes service, 'zuiRoot + "/Components/Builtins/"'
    assert_includes renderer, 'bridge.zuiRoot + "/ControlNode.qml"'
    refute_includes service, 'pluginDir + "/Components/Builtins/"'
  end

  def test_application_code_is_not_present_in_adapter_sources
    markers = %w[restaurant_drinks tesla_drive_dashboard shader_studio cardiac_health_monitor]
    sources = Dir[File.join(ROOT, "{lib,runtime}", "**", "*")].select { |path| File.file?(path) }
    leaks = sources.flat_map do |path|
      content = File.binread(path)
      markers.filter_map { |marker| path if content.include?(marker) }
    end

    assert_empty leaks
  end
end
