# frozen_string_literal: true

require_relative "lib/omarchy_ui"

Gem::Specification.new do |spec|
  spec.name = "omarchy-ui"
  spec.version = OmarchyUI::VERSION
  spec.summary = "Build native Omarchy plugins and applications in Ruby"
  spec.description = "A persistent Ruby runtime, reactive UI model, and safe QML renderer for Omarchy."
  spec.authors = ["Adam Moussa Ali"]
  spec.license = "MIT"
  spec.homepage = "https://github.com/AdamMusa/omarchy-ui"
  spec.platform = Gem::Platform.new("x86_64-linux")
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["documentation_uri"] = "#{spec.homepage}#readme"
  spec.required_ruby_version = ">= 3.1"
  spec.files = Dir["bin/*", "lib/**/*.rb", "*.qml", "Components/**/*", "vendor/runtime/**/*", "manifest.json", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]
  spec.bindir = "bin"
  spec.executables = ["omarchy_ui"]
end
