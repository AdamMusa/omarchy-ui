#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "omarchy_ui"

options = {}
parser = OptionParser.new do |flags|
  flags.banner = "Usage: script/verify-plugin-package.rb [--output FILE] PLUGIN_DIRECTORY"
  flags.on("--output FILE", "Write the JSON verification report to FILE") { |path| options[:output] = path }
end
begin
  parser.parse!
  raise OptionParser::MissingArgument, "expected one plugin directory" unless ARGV.length == 1

  report = OmarchyUI::ArtifactVerifier.verify!(ARGV.first)
  json = JSON.pretty_generate(report) + "\n"
  File.write(options.fetch(:output), json) if options[:output]
  $stdout.write(json)
rescue StandardError => error
  warn "artifact verification failed: #{error.message}"
  exit 1
end
