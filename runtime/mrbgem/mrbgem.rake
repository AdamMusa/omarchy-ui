MRuby::Gem::Specification.new("omarchy-ui-runtime") do |spec|
  spec.license = "MIT"
  spec.author = "Adam Moussa Ali"
  spec.summary = "Embedded Zui core with the Omarchy adapter for mruby"

  framework = File.expand_path("../..", __dir__)
  zui_root = File.expand_path(ENV["ZUI_SOURCE_DIR"] || File.join(framework, "..", "zui"))
  raise "Zui source tree not found: #{zui_root}" unless File.file?(File.join(zui_root, "lib", "zui.rb"))

  runtime_files = %w[
    protocol value state_store node animation scheduler component_registry
    components builder application
  ].map { |name| File.join(zui_root, "lib", "zui", "#{name}.rb") }
  spec.rbfiles = [
    File.join(__dir__, "mrblib", "bootstrap.rb"),
    *runtime_files,
    File.join(__dir__, "mrblib", "omarchy_adapter.rb"),
    File.join(__dir__, "mrblib", "entrypoint.rb")
  ]
end
