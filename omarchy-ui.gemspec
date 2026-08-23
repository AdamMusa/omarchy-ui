# frozen_string_literal: true

require_relative "lib/omarchy_ui"

Gem::Specification.new do |spec|
  spec.name = "omarchy-ui"
  spec.version = OmarchyUI::VERSION
  spec.summary = "Build native Omarchy plugins and applications in Ruby"
  spec.description = "The application framework for building native Omarchy apps with Ruby."
  spec.authors = ["Adam Moussa Ali"]
  spec.license = "MIT"
  spec.homepage = "https://github.com/AdamMusa/omarchy-ui"
  spec.platform = Gem::Platform.new("x86_64-linux")
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["documentation_uri"] = "#{spec.homepage}#readme"
  spec.metadata["release_status"] = "experimental"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.required_ruby_version = ">= 3.1"
  spec.files = Dir["bin/*", "lib/**/*.rb", "*.qml", "Components/**/*", "vendor/runtime/**/*", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]
  spec.bindir = "bin"
  spec.executables = ["omarchy_ui"]
end
