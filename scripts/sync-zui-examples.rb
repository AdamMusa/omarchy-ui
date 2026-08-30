#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "open3"

MODE = ARGV.fetch(0, "--check")
abort "usage: #{$PROGRAM_NAME} [--check|--sync]" unless %w[--check --sync].include?(MODE)

REPOSITORY_ROOT = File.expand_path("..", __dir__)
ZUI_ROOT = File.expand_path(ENV.fetch("ZUI_SOURCE_DIR", File.join(REPOSITORY_ROOT, "..", "zui")))
SOURCE_ROOT = File.join(ZUI_ROOT, "examples")
TARGET_ROOT = File.join(REPOSITORY_ROOT, "examples")
REVISION_FILE = File.join(TARGET_ROOT, "ZUI_SOURCE_REVISION")
IGNORED_SEGMENTS = %w[dist tmp].freeze
ZUI_HOST_ONLY_FILES = %w[
  .DS_Store Gemfile Gemfile.lock config.rb ruby.icns ruby.ico ruby.jpg ruby.png
].freeze
ADAPTER_ENTRYPOINT = "main.rb"
ADAPTER_README = "README.md"
ADAPTER_RUNTIME_CHECK = "test/runtime_check.rb"
ADAPTER_FILES = [ADAPTER_ENTRYPOINT, ADAPTER_README].freeze

abort "Zui examples not found at #{SOURCE_ROOT}; set ZUI_SOURCE_DIR" unless File.directory?(SOURCE_ROOT)

def applications(root)
  Dir.children(root).sort.select do |entry|
    File.file?(File.join(root, entry, "app.rb"))
  end
end

def application_files(root, application)
  base = File.join(root, application)
  Dir.glob("**/*", File::FNM_DOTMATCH, base: base).sort.select do |relative|
    next false if relative == "." || relative == ".."
    next false if relative.split(File::SEPARATOR).any? { |segment| IGNORED_SEGMENTS.include?(segment) }
    next false if ZUI_HOST_ONLY_FILES.include?(File.basename(relative))

    File.file?(File.join(base, relative))
  end
end

def application_constant(source_root, application)
  main = File.read(File.join(source_root, application, "main.rb"))
  match = main.match(/^([A-Z][A-Za-z0-9_:]*)\.run\s*$/)
  abort "cannot identify the application module in #{application}/main.rb" unless match

  match[1]
end

def adapter_source(source_root, application)
  constant = application_constant(source_root, application)
  <<~RUBY
    # frozen_string_literal: true

    require "omarchy_ui"
    require_relative "app"

    OmarchyUI.run(#{constant})
  RUBY
end

def adapter_readme_source(source_root, application)
  source = File.read(File.join(source_root, application, ADAPTER_README))
      .gsub("../../bin/zui run main.rb", "omarchy_ui run main.rb")
      .gsub("zui run main.rb", "omarchy_ui run main.rb")
      .sub(/\n## Distribution\n.*\z/m, "")
  "#{source.rstrip}\n"
end

def adapter_runtime_check_source(source_root, application)
  File.read(File.join(source_root, application, ADAPTER_RUNTIME_CHECK))
      .gsub('require_relative "../app"', 'require_relative "app"')
end

def adapter_files(source_root, application)
  files = ADAPTER_FILES.dup
  runtime_check = File.join(source_root, application, ADAPTER_RUNTIME_CHECK)
  files << ADAPTER_RUNTIME_CHECK if File.file?(runtime_check)
  files
end

def git_revision(root)
  output, status = Open3.capture2("git", "-C", root, "rev-parse", "HEAD")
  abort "cannot read the Zui Git revision from #{root}" unless status.success?

  output.strip
end

source_apps = applications(SOURCE_ROOT)
abort "no Zui applications found at #{SOURCE_ROOT}" if source_apps.empty?

if MODE == "--sync"
  dirty, status = Open3.capture2("git", "-C", ZUI_ROOT, "status", "--porcelain", "--", "examples")
  abort "cannot inspect the Zui examples" unless status.success?
  abort "Zui examples have uncommitted changes; commit them before synchronizing" unless dirty.empty?

  source_apps.each do |application|
    application_adapter_files = adapter_files(SOURCE_ROOT, application)
    application_files(SOURCE_ROOT, application).each do |relative|
      next if application_adapter_files.include?(relative)

      source = File.join(SOURCE_ROOT, application, relative)
      target = File.join(TARGET_ROOT, application, relative)
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp(source, target, preserve: true)
    end

    File.write(
      File.join(TARGET_ROOT, application, ADAPTER_ENTRYPOINT),
      adapter_source(SOURCE_ROOT, application)
    )
    File.write(
      File.join(TARGET_ROOT, application, ADAPTER_README),
      adapter_readme_source(SOURCE_ROOT, application)
    )
    if application_adapter_files.include?(ADAPTER_RUNTIME_CHECK)
      File.write(
        File.join(TARGET_ROOT, application, ADAPTER_RUNTIME_CHECK),
        adapter_runtime_check_source(SOURCE_ROOT, application)
      )
    end
  end

  File.write(REVISION_FILE, "#{git_revision(ZUI_ROOT)}\n")
end

errors = []
target_apps = applications(TARGET_ROOT)
errors << "application catalog differs: Zui=#{source_apps.inspect}, Omarchy=#{target_apps.inspect}" unless target_apps == source_apps

source_apps.each do |application|
  application_adapter_files = adapter_files(SOURCE_ROOT, application)
  source_files = application_files(SOURCE_ROOT, application)
  shared_files = source_files - application_adapter_files
  target_files = application_files(TARGET_ROOT, application)
  expected_files = shared_files + application_adapter_files
  unexpected = target_files - expected_files
  missing = expected_files - target_files
  errors << "#{application}: unexpected adapter files: #{unexpected.join(', ')}" unless unexpected.empty?
  errors << "#{application}: missing shared files: #{missing.join(', ')}" unless missing.empty?

  shared_files.each do |relative|
    source = File.join(SOURCE_ROOT, application, relative)
    target = File.join(TARGET_ROOT, application, relative)
    next unless File.file?(target)
    next if FileUtils.compare_file(source, target)

    errors << "#{application}/#{relative} differs from Zui"
  end

  adapter = File.join(TARGET_ROOT, application, ADAPTER_ENTRYPOINT)
  errors << "#{application}/#{ADAPTER_ENTRYPOINT} is missing or stale" unless File.file?(adapter) && File.read(adapter) == adapter_source(SOURCE_ROOT, application)
  readme = File.join(TARGET_ROOT, application, ADAPTER_README)
  errors << "#{application}/#{ADAPTER_README} is missing or stale" unless File.file?(readme) && File.read(readme) == adapter_readme_source(SOURCE_ROOT, application)
  if application_adapter_files.include?(ADAPTER_RUNTIME_CHECK)
    runtime_check = File.join(TARGET_ROOT, application, ADAPTER_RUNTIME_CHECK)
    errors << "#{application}/#{ADAPTER_RUNTIME_CHECK} is missing or stale" unless File.file?(runtime_check) && File.read(runtime_check) == adapter_runtime_check_source(SOURCE_ROOT, application)
  end
end

expected_revision = git_revision(ZUI_ROOT)
actual_revision = File.file?(REVISION_FILE) ? File.read(REVISION_FILE).strip : nil
errors << "ZUI_SOURCE_REVISION is #{actual_revision.inspect}, expected #{expected_revision}" unless actual_revision == expected_revision

abort errors.join("\n") unless errors.empty?

puts "#{source_apps.length} Omarchy showcase adapters match Zui #{expected_revision[0, 12]}."
