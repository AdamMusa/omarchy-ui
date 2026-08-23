# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require_relative "../lib/omarchy_ui"

class FrameworkBoundaryTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  ADAPTER_QML = %w[App.qml BarWidget.qml Panel.qml Service.qml].freeze
  REMOVED_CORE_FILES = %w[
    animation application builder command component_registry components node protocol
    scheduler source_bundle state_store value
  ].map { |name| File.join(ROOT, "lib", "omarchy_ui", "#{name}.rb") }.freeze

  def test_gem_is_an_explicit_zui_adapter
    specification = Gem::Specification.load(File.join(ROOT, "omarchy-ui.gemspec"))
    dependency = specification.dependencies.find { |candidate| candidate.name == "zui" }

    refute_nil dependency
    assert dependency.requirement.satisfied_by?(Gem::Version.new(Zui::VERSION))
    assert_empty specification.files.grep(%r{\AComponents/})
    assert_empty specification.files.grep(%r{\Alib/omarchy_ui/(?:animation|application|builder|node)\.rb\z})
  end

  def test_ruby_api_delegates_to_the_same_zui_core_objects
    assert_same Zui::Application, OmarchyUI::Application
    assert_same Zui::Builder, OmarchyUI::Builder
    assert_same Zui::StateStore, OmarchyUI::StateStore
    assert_same Zui::COMPONENTS, OmarchyUI::COMPONENTS
    assert_operator OmarchyUI::SourceBundle, :<, Zui::SourceBundle
  end

  def test_repository_contains_only_the_omarchy_adapter_surface
    assert_empty REMOVED_CORE_FILES.select { |path| File.exist?(path) }
    refute Dir.exist?(File.join(ROOT, "Components"))
    refute File.exist?(File.join(ROOT, "ControlNode.qml"))
    assert_equal ADAPTER_QML, Dir[File.join(ROOT, "*.qml")].map { |path| File.basename(path) }.sort
  end

  def test_adapter_runtime_installs_zui_catalog_and_omarchy_host
    Dir.mktmpdir do |directory|
      OmarchyUI::Runtime.install_package(directory)

      assert_equal File.read(File.join(ROOT, "Service.qml")), File.read(File.join(directory, "Service.qml"))
      assert_equal File.read(File.join(Zui::FRAMEWORK_ROOT, "ControlNode.qml")), File.read(File.join(directory, "ControlNode.qml"))
      assert File.file?(File.join(directory, "Components", "Builtins", "ModelView3d.qml"))
      assert File.file?(File.join(directory, "Controls", "Button.qml"))
      assert File.file?(File.join(directory, "Theme", "Style.qml"))
      refute File.exist?(File.join(directory, "Desktop.qml"))
    end
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
