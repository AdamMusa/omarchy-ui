# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

module OmarchyUI
  class ArtifactVerifier
    class Mismatch < StandardError; end

    def self.verify!(path)
      new(path).verify!
    end

    def initialize(path)
      @path = File.expand_path(path)
    end

    def verify!
      manifest = PluginPackage.validate!(@path)
      shipped = file_map(@path)
      expected = derived_file_map(@path)

      rebuilt = Dir.mktmpdir("omarchy-ui-artifact-verification-") do |temporary|
        copy_package(temporary)
        Runtime.install_package(temporary, project: temporary, compiled: true)
        PluginPackage.validate!(temporary)
        derived_file_map(temporary)
      end

      mismatches = compare(expected, rebuilt)
      unless mismatches.empty?
        raise Mismatch, "rebuild did not match shipped artifacts:\n#{mismatches.join("\n")}"
      end

      {
        "schema_version" => 1,
        "verified" => true,
        "plugin" => manifest.slice("id", "name", "version"),
        "source" => {
          "main.rb" => shipped.fetch("main.rb"),
          "manifest.json" => shipped.fetch("manifest.json"),
          "repository" => git_value("config", "--get", "remote.origin.url"),
          "commit" => git_value("rev-parse", "HEAD")
        }.compact,
        "toolchain" => toolchain,
        "derived_artifacts" => expected,
        "shipped_files" => shipped
      }
    end

    private

    def copy_package(destination)
      Dir.children(@path).sort.each do |entry|
        next if PluginPackage::SOURCE_CONTROL_ENTRIES.include?(entry)

        FileUtils.cp_r(File.join(@path, entry), destination, preserve: true)
      end
    end

    def derived_file_map(root)
      compiled = QmlCompiler.verify!(root)
      paths = compiled.fetch("entry_shims") + ["omarchy-ui-runtime"]
      paths.concat(compiled.fetch("artifacts").map { |artifact| artifact.fetch("path") })
      paths << File.join(compiled.fetch("module_path"), "qmldir")
      paths.sort.to_h { |relative| [relative, file_record(File.join(root, relative))] }
    end

    def file_map(root)
      Dir.glob(File.join(root, "**", "*"), File::FNM_DOTMATCH)
        .select { |path| File.file?(path) && !inside_source_control?(path) }
        .sort
        .to_h { |path| [path.delete_prefix("#{root}/"), file_record(path)] }
    end

    def inside_source_control?(path)
      relative = path.delete_prefix("#{@path}/")
      PluginPackage::SOURCE_CONTROL_ENTRIES.any? do |entry|
        relative == entry || relative.start_with?("#{entry}/")
      end
    end

    def file_record(path)
      {
        "sha256" => Digest::SHA256.file(path).hexdigest,
        "bytes" => File.size(path)
      }
    end

    def compare(expected, rebuilt)
      (expected.keys | rebuilt.keys).sort.filter_map do |path|
        next if expected[path] == rebuilt[path]

        "#{path}: shipped=#{expected[path]&.fetch("sha256", "missing")} " \
          "rebuilt=#{rebuilt[path]&.fetch("sha256", "missing")}"
      end
    end

    def git_value(*arguments)
      output, _error, status = Open3.capture3("git", "-C", @path, *arguments)
      value = output.strip
      value unless !status.success? || value.empty?
    rescue Errno::ENOENT
      nil
    end

    def toolchain
      compiler = QmlCompiler.new(@path)
      tools = compiler.send(:build_tools)
      {
        "omarchy_ui" => VERSION,
        "zui" => ZUI_VERSION,
        "qt" => command_output(tools.fetch(:qtpaths), "--query", "QT_VERSION"),
        "cmake" => command_output(tools.fetch(:cmake), "--version").lines.first.to_s.strip,
        "compiler" => command_output(tools.fetch(:compiler), "--version").lines.first.to_s.strip
      }
    end

    def command_output(*arguments)
      output, error, status = Open3.capture3(*arguments)
      raise ArgumentError, "toolchain command failed: #{arguments.first}: #{error.strip}" unless status.success?

      output.strip
    end
  end
end
