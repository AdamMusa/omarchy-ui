# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
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

    def self.compile!(path, entry_files: ENTRY_TYPES.keys)
      new(path, entry_files:).compile!
    end

    def self.verify!(path)
      new(path).verify!
    end

    def initialize(path, entry_files: nil)
      @path = File.expand_path(path)
      @entry_types = entry_files ? select_entry_types(entry_files) : nil
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
        deploy!(build:, module_path:, target:, uri:, expected_qt_version: qt_version)
      end
    end

    def verify!
      entry_types = packaged_entry_types
      module_path, module_uri = packaged_module
      entry_types.each do |entry, type|
        shim = File.read(File.join(@path, entry)).strip
        expected = entry_shim(module_path, type, uri: module_uri).strip
        raise ArgumentError, "invalid compiled QML entry shim: #{entry}" unless shim == expected
      end

      segment = File.basename(module_path)
      target = "omarchy_ui_bundle_#{segment.downcase}"
      artifact_names = ["lib#{target}.so", "lib#{target}plugin.so"]
      module_directory = File.join(@path, module_path)
      expected_module_entries = (artifact_names + ["qmldir"]).sort
      unless Dir.children(module_directory).sort == expected_module_entries
        raise ArgumentError, "compiled QML module contains unexpected files"
      end
      artifacts = artifact_names.map do |name|
        relative = File.join(module_path, name)
        absolute = File.join(@path, relative)
        {
          "path" => relative,
          "sha256" => Digest::SHA256.file(absolute).hexdigest,
          "bytes" => File.size(absolute)
        }
      end
      {
        "format" => "qt-aot-qml-module",
        "format_version" => FORMAT_VERSION,
        "module_uri" => module_uri,
        "module_path" => module_path,
        "entry_shims" => entry_types.keys,
        "artifacts" => artifacts
      }
    end

    private

    def select_entry_types(entry_files)
      entries = Array(entry_files).map(&:to_s).uniq
      unknown = entries - ENTRY_TYPES.keys
      raise ArgumentError, "unsupported compiled QML entries: #{unknown.join(', ')}" unless unknown.empty?
      raise ArgumentError, "compiled QML package needs at least one entry point" if entries.empty?

      entries.to_h { |entry| [entry, ENTRY_TYPES.fetch(entry)] }
    end

    def packaged_entry_types
      selected = if File.file?(File.join(@path, "manifest.json"))
        manifest = JSON.parse(File.read(File.join(@path, "manifest.json")))
        select_entry_types(manifest.fetch("entryPoints").values)
      else
        select_entry_types(ENTRY_TYPES.keys.select { |entry| File.file?(File.join(@path, entry)) })
      end
      actual = ENTRY_TYPES.keys.select { |entry| File.file?(File.join(@path, entry)) }
      unless actual.sort == selected.keys.sort
        raise ArgumentError, "compiled QML package contains unexpected entry shims"
      end
      selected
    rescue JSON::ParserError, KeyError, TypeError => error
      raise ArgumentError, "invalid plugin manifest: #{error.message}"
    end

    def packaged_module
      compiled_root = File.join(@path, COMPILED_ROOT)
      unless File.directory?(compiled_root) && !File.symlink?(compiled_root) &&
          Dir.children(compiled_root) == ["Bundles"]
        raise ArgumentError, "compiled QML root must contain only the Bundles directory"
      end
      bundles = File.join(compiled_root, "Bundles")
      directories = if File.directory?(bundles) && !File.symlink?(bundles)
        Dir.children(bundles).sort.filter_map do |entry|
          path = File.join(bundles, entry)
          path if File.directory?(path) && !File.symlink?(path)
        end
      else
        []
      end
      raise ArgumentError, "compiled QML package must contain exactly one module" unless directories.length == 1

      directory = directories.first
      module_path = directory.delete_prefix("#{@path}/")
      qmldir = File.join(directory, "qmldir")
      unless File.file?(qmldir) && !File.symlink?(qmldir)
        raise ArgumentError, "compiled QML qmldir is missing"
      end
      module_uri = File.read(qmldir)[/^module\s+(\S+)\s*$/, 1]
      raise ArgumentError, "compiled QML module declaration is missing" unless module_uri
      unless File.join(*module_uri.split(".")) == module_path
        raise ArgumentError, "compiled QML module path does not match its URI"
      end

      [module_path, module_uri]
    end

    def validate_sources!
      missing = @entry_types.keys.reject { |entry| File.file?(File.join(@path, entry)) }
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
      (@entry_types.keys + SOURCE_ENTRIES.drop(ENTRY_TYPES.length)).each do |entry|
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

    def deploy!(build:, module_path:, target:, uri:, expected_qt_version:)
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
      qmldir = File.join(destination, "qmldir")
      File.write(qmldir, File.read(qmldir).rstrip + "\n")

      SOURCE_ENTRIES.each { |entry| remove_generated(File.join(@path, entry)) }
      @entry_types.each do |entry, type|
        File.write(File.join(@path, entry), entry_shim(module_path, type, uri:))
      end
      verify!
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

  end
end
