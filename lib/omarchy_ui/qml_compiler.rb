# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "pathname"
require "tmpdir"

module OmarchyUI
  class QmlCompiler
    FORMAT_VERSION = 1
    ENTRY_TYPES = {
      "App.qml" => "App",
      "BarWidget.qml" => "BarWidget",
      "Panel.qml" => "Panel",
      "Service.qml" => "Service"
    }.freeze
    SOURCE_ENTRIES = (ENTRY_TYPES.keys + %w[ControlNode.qml Components Controls Theme Fonts]).freeze
    COMPILED_ROOT = "OmarchyUI"
    REPORT = "omarchy-ui-qml-bundle.json"
    CHECKSUM = "omarchy-ui-qml-bundle.sha256"
    PROVENANCE = "QML_PROVENANCE.md"

    def self.compile!(path)
      new(path).compile!
    end

    def self.verify!(path)
      new(path).verify!
    end

    def initialize(path)
      @path = File.expand_path(path)
    end

    def compile!
      validate_sources!
      tools = build_tools
      qt_version = qt_version!(tools.fetch(:qtpaths))

      Dir.mktmpdir("omarchy-ui-qml-compile-") do |temporary|
        source = File.join(temporary, "source")
        build = File.join(temporary, "build")
        stage_sources(source)
        qml_files = relative_files(source, "**/*.qml")
        resources = relative_files(source, "Fonts/**/*") +
          %w[Controls/qmldir Theme/qmldir].select { |entry| File.file?(File.join(source, entry)) }
        fingerprint = source_fingerprint(source, qml_files + resources, qt_version:)
        segment = "B#{fingerprint[0, 20]}"
        uri = "OmarchyUI.Bundles.#{segment}"
        target = "omarchy_ui_bundle_#{segment.downcase}"
        module_path = File.join(*uri.split("."))

        File.write(File.join(source, "CMakeLists.txt"), cmake_project(
          qml_files:,
          resources: resources.sort,
          uri:,
          target:,
          module_path:
        ))
        configure!(tools.fetch(:qt_cmake), source, build)
        build!(tools.fetch(:cmake), build)
        deploy!(
          build:,
          module_path:,
          target:,
          uri:,
          fingerprint:,
          qml_files:,
          resources:,
          source:,
          expected_qt_version: qt_version
        )
      end
    end

    def verify!
      report_path = File.join(@path, REPORT)
      raise ArgumentError, "compiled QML report is missing: #{report_path}" unless File.file?(report_path)

      report = JSON.parse(File.read(report_path))
      unless report["format"] == "qt-aot-qml-module" && report["format_version"] == FORMAT_VERSION
        raise ArgumentError, "unsupported compiled QML package format"
      end
      ENTRY_TYPES.each_key do |entry|
        raise ArgumentError, "compiled QML entry shim is missing: #{entry}" unless File.file?(File.join(@path, entry))
      end
      module_path = safe_relative_path(report.fetch("module_path"))
      raise ArgumentError, "compiled QML qmldir is missing" unless File.file?(File.join(@path, module_path, "qmldir"))

      artifacts = report.fetch("artifacts")
      raise ArgumentError, "compiled QML package must contain two libraries" unless artifacts.length == 2
      artifacts.each do |artifact|
        relative = safe_relative_path(artifact.fetch("path"))
        unless relative.start_with?("#{module_path}/") && relative.end_with?(".so")
          raise ArgumentError, "compiled QML artifact is outside its module: #{relative}"
        end
        absolute = File.join(@path, relative)
        raise ArgumentError, "compiled QML artifact is missing: #{relative}" unless File.file?(absolute)
        unless File.size(absolute) == artifact.fetch("bytes") &&
            Digest::SHA256.file(absolute).hexdigest == artifact.fetch("sha256")
          raise ArgumentError, "compiled QML artifact checksum mismatch: #{relative}"
        end
      end
      report
    rescue JSON::ParserError, KeyError, TypeError => error
      raise ArgumentError, "invalid compiled QML report: #{error.message}"
    end

    private

    def safe_relative_path(path)
      value = path.to_s
      clean = File.expand_path(value, @path)
      unless !value.empty? && !Pathname.new(value).absolute? && clean.start_with?("#{@path}/")
        raise ArgumentError, "unsafe compiled QML path: #{value.inspect}"
      end
      clean.delete_prefix("#{@path}/")
    end

    def validate_sources!
      missing = ENTRY_TYPES.keys.reject { |entry| File.file?(File.join(@path, entry)) }
      missing << "ControlNode.qml" unless File.file?(File.join(@path, "ControlNode.qml"))
      return if missing.empty?

      raise ArgumentError, "cannot compile QML; generated files are missing: #{missing.join(', ')}"
    end

    def build_tools
      {
        qt_cmake: find_executable("/usr/lib/qt6/bin/qt-cmake", "qt-cmake"),
        qtpaths: find_executable("/usr/lib/qt6/bin/qtpaths", "qtpaths6", "qtpaths"),
        cmake: find_executable("cmake"),
        ninja: find_executable("ninja"),
        compiler: find_executable("c++", "g++", "clang++")
      }
    end

    def qt_version!(qtpaths)
      output, error, status = Open3.capture3(qtpaths, "--query", "QT_VERSION")
      version = output.strip
      return version if status.success? && !version.empty?

      detail = error.strip
      raise ArgumentError, "could not determine the Qt build version#{detail.empty? ? '' : ": #{detail}"}"
    end

    def find_executable(*candidates)
      candidates.each do |candidate|
        if candidate.include?(File::SEPARATOR)
          return candidate if File.file?(candidate) && File.executable?(candidate)
          next
        end

        ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).each do |directory|
          path = File.join(directory, candidate)
          return path if File.file?(path) && File.executable?(path)
        end
      end
      raise ArgumentError, "compiled QML packaging requires #{candidates.first}"
    end

    def stage_sources(destination)
      FileUtils.mkdir_p(destination)
      SOURCE_ENTRIES.each do |entry|
        source = File.join(@path, entry)
        next unless File.exist?(source)

        FileUtils.cp_r(source, File.join(destination, entry))
      end
    end

    def relative_files(root, pattern)
      Dir.glob(File.join(root, pattern), File::FNM_DOTMATCH)
        .select { |path| File.file?(path) }
        .map { |path| path.delete_prefix("#{root}/") }
        .sort
    end

    def source_fingerprint(root, files, qt_version:)
      digest = Digest::SHA256.new
      digest << "omarchy-ui-qml-bundle\0" << FORMAT_VERSION.to_s << "\0"
      digest << "qt\0" << qt_version << "\0"
      files.sort.each do |relative|
        digest << relative << "\0" << File.binread(File.join(root, relative)) << "\0"
      end
      digest.hexdigest
    end

    def cmake_project(qml_files:, resources:, uri:, target:, module_path:)
      <<~CMAKE
        cmake_minimum_required(VERSION 3.21)

        project(OmarchyUICompiledBundle LANGUAGES CXX)

        find_package(Qt6 6.8 REQUIRED COMPONENTS Core Qml Quick QuickControls2)
        qt_standard_project_setup(REQUIRES 6.8)

        qt_add_library(#{target} SHARED)
        qt_add_qml_module(#{target}
          URI #{uri}
          VERSION 1.0
          OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/#{module_path}"
          QML_FILES
        #{cmake_entries(qml_files)}
          RESOURCES
        #{cmake_entries(resources)}
          DISCARD_QML_CONTENTS
          NO_LINT
        )

        set(module_output "${CMAKE_BINARY_DIR}/#{module_path}")
        set_target_properties(
          #{target}
          #{target}plugin
          PROPERTIES
            LIBRARY_OUTPUT_DIRECTORY "${module_output}"
            BUILD_RPATH "\\$ORIGIN"
            BUILD_WITH_INSTALL_RPATH TRUE
            INSTALL_RPATH "\\$ORIGIN"
        )

        target_compile_options(
          #{target}
          PRIVATE
            "-ffile-prefix-map=${CMAKE_CURRENT_SOURCE_DIR}=."
            "-ffile-prefix-map=${CMAKE_CURRENT_BINARY_DIR}=."
        )
        target_compile_options(
          #{target}plugin
          PRIVATE
            "-ffile-prefix-map=${CMAKE_CURRENT_SOURCE_DIR}=."
            "-ffile-prefix-map=${CMAKE_CURRENT_BINARY_DIR}=."
        )
        target_link_options(#{target} PRIVATE "-Wl,--build-id=none")
        target_link_options(#{target}plugin PRIVATE "-Wl,--build-id=none")
        target_link_libraries(
          #{target}
          PRIVATE Qt6::Core Qt6::Qml Qt6::Quick Qt6::QuickControls2
        )

        file(WRITE "${CMAKE_BINARY_DIR}/qt-version.txt" "${Qt6Core_VERSION}\n")
      CMAKE
    end

    def cmake_entries(entries)
      entries.map { |entry| "    #{cmake_string(entry)}" }.join("\n")
    end

    def cmake_string(value)
      escaped = value.gsub("\\", "\\\\").gsub('"', '\\"')
      %Q("#{escaped}")
    end

    def configure!(qt_cmake, source, build)
      run_build_command!(
        "QML configure",
        qt_cmake,
        "-S", source,
        "-B", build,
        "-G", "Ninja",
        "-DCMAKE_BUILD_TYPE=Release"
      )
    end

    def build!(cmake, build)
      run_build_command!("QML compilation", cmake, "--build", build, "--parallel")
    end

    def run_build_command!(label, *command)
      environment = {
        "LC_ALL" => "C.UTF-8",
        "SOURCE_DATE_EPOCH" => "1",
        "TZ" => "UTC"
      }
      output, error, status = Open3.capture3(environment, *command)
      return if status.success?

      detail = "#{output}\n#{error}".lines.last(40).join.strip
      raise ArgumentError, "#{label} failed#{detail.empty? ? '' : ":\n#{detail}"}"
    end

    def deploy!(build:, module_path:, target:, uri:, fingerprint:, qml_files:, resources:, source:,
      expected_qt_version:)
      built_module = File.join(build, module_path)
      artifact_names = ["lib#{target}.so", "lib#{target}plugin.so", "qmldir"]
      missing = artifact_names.reject { |name| File.file?(File.join(built_module, name)) }
      unless missing.empty?
        raise ArgumentError, "QML compilation did not produce: #{missing.join(', ')}"
      end
      qt_version = File.read(File.join(build, "qt-version.txt")).strip
      unless qt_version == expected_qt_version
        raise ArgumentError,
          "Qt compiler mismatch: qtpaths reported #{expected_qt_version}, CMake found #{qt_version}"
      end

      compiled_root = File.join(@path, COMPILED_ROOT)
      FileUtils.remove_entry(compiled_root) if File.directory?(compiled_root)
      destination = File.join(@path, module_path)
      FileUtils.mkdir_p(destination)
      artifact_names.each { |name| FileUtils.cp(File.join(built_module, name), destination) }

      SOURCE_ENTRIES.each { |entry| remove_generated(File.join(@path, entry)) }
      ENTRY_TYPES.each do |entry, type|
        File.write(File.join(@path, entry), entry_shim(module_path, type, uri:))
      end

      artifact_paths = artifact_names.filter_map do |name|
        next if name == "qmldir"

        relative = File.join(module_path, name)
        absolute = File.join(@path, relative)
        {
          "path" => relative,
          "sha256" => Digest::SHA256.file(absolute).hexdigest,
          "bytes" => File.size(absolute)
        }
      end
      report = {
        "format" => "qt-aot-qml-module",
        "format_version" => FORMAT_VERSION,
        "qt_version" => qt_version,
        "module_uri" => uri,
        "module_path" => module_path,
        "source_fingerprint" => fingerprint,
        "source_files" => qml_files.length,
        "source_bytes" => (qml_files + resources).sum { |file| File.size(File.join(source, file)) },
        "entry_shims" => ENTRY_TYPES.keys,
        "artifacts" => artifact_paths
      }
      File.write(File.join(@path, REPORT), JSON.pretty_generate(report) + "\n")
      checksums = artifact_paths.map { |artifact| "#{artifact.fetch('sha256')}  #{artifact.fetch('path')}" }
      File.write(File.join(@path, CHECKSUM), checksums.join("\n") + "\n")
      File.write(File.join(@path, PROVENANCE), provenance(report))
      report
    end

    def remove_generated(path)
      File.directory?(path) ? FileUtils.remove_entry(path) : FileUtils.rm_f(path)
    end

    def entry_shim(module_path, type, uri:)
      import = type == "App" ? uri : %Q("#{module_path}")
      <<~QML
        import QtQuick
        import #{import} as Compiled

        Compiled.#{type} {}
      QML
    end

    def provenance(report)
      artifacts = report.fetch("artifacts").map do |artifact|
        "- `#{artifact.fetch('path')}` — `#{artifact.fetch('sha256')}`"
      end.join("\n")
      <<~MARKDOWN
        # Compiled QML provenance

        Omarchy UI generated this package's native Qt module from the tree-shaken Zui and
        Omarchy host QML graph. Generated QML source contents were discarded after AOT compilation.

        - Format: `#{report.fetch('format')}` version #{report.fetch('format_version')}
        - Qt: `#{report.fetch('qt_version')}`
        - Module: `#{report.fetch('module_uri')}`
        - Source fingerprint: `#{report.fetch('source_fingerprint')}`

        ## Artifacts

        #{artifacts}

        Verify the packaged libraries from the plugin directory:

        ```bash
        sha256sum --check #{CHECKSUM}
        ```

        `App.qml`, `Service.qml`, `Panel.qml`, and `BarWidget.qml` are the minimal loader shims
        required by Omarchy's file-based entry-point contract. Application UI lives in the compiled
        module recorded by `#{REPORT}`.
      MARKDOWN
    end
  end
end
