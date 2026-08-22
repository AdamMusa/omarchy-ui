MRuby::Gem::Specification.new("omarchy-ui-runtime") do |spec|
  spec.license = "MIT"
  spec.author = "Adam Moussa Ali"
  spec.summary = "Embedded Omarchy UI framework for mruby"

  framework = File.expand_path("../..", __dir__)
  runtime_files = %w[
    protocol value state_store node animation scheduler component_registry
    components builder application
  ].map { |name| File.join(framework, "lib", "omarchy_ui", "#{name}.rb") }
  spec.rbfiles = [
    File.join(__dir__, "mrblib", "bootstrap.rb"),
    *runtime_files,
    File.join(__dir__, "mrblib", "entrypoint.rb")
  ]
end
