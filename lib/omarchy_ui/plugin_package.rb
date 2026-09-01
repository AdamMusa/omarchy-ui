# frozen_string_literal: true

require "json"

module OmarchyUI
  class PluginPackage
    DEVELOPMENT_ENTRIES = %w[
      .github .gitattributes .gitignore audit build config.rb dist docs qml-source spec test tests vendor
    ].freeze
    SOURCE_CONTROL_ENTRIES = %w[.git].freeze
    README_PATTERN = /\Areadme(?:\.[^.]+)?\z/i
    LICENSE_PATTERN = /\A(?:license|copying)(?:\.[^.]+)?\z/i
    REQUIRED_MANIFEST_STRINGS = %w[id name version author license description].freeze

    def self.validate!(path)
      new(path).validate!
    end

    def initialize(path)
      @path = File.expand_path(path)
    end

    def validate!
      validate_root_files!
      manifest = read_manifest
      validate_manifest!(manifest)
      validate_readme!(manifest)
      validate_runtime!
      validate_ruby_surface!
      validate_qml_surface!(manifest)
      QmlCompiler.verify!(@path)
      manifest
    end

    private

    def validate_root_files!
      entries = Dir.children(@path)
      forbidden = entries & (DEVELOPMENT_ENTRIES + Runtime::LEGACY_METADATA_FILES)
      unless forbidden.empty?
        raise ArgumentError, "plugin package contains development-only entries: #{forbidden.sort.join(', ')}"
      end

      manifests = Dir.glob(File.join(@path, "**", "manifest.json"), File::FNM_DOTMATCH)
        .select { |path| File.file?(path) }
      unless manifests == [File.join(@path, "manifest.json")]
        raise ArgumentError, "plugin package must contain exactly one root manifest.json"
      end

      readmes = entries.grep(README_PATTERN).select { |entry| File.file?(File.join(@path, entry)) }
      raise ArgumentError, "plugin package needs one root README" unless readmes.length == 1

      licenses = entries.grep(LICENSE_PATTERN).select { |entry| File.file?(File.join(@path, entry)) }
      raise ArgumentError, "plugin package needs one root license file" unless licenses.length == 1

      symlinks = Dir.glob(File.join(@path, "**", "*"), File::FNM_DOTMATCH)
        .select { |path| File.symlink?(path) }
      unless symlinks.empty?
        raise ArgumentError, "plugin package may not contain symbolic links"
      end
    end

    def read_manifest
      JSON.parse(File.read(File.join(@path, "manifest.json")))
    rescue JSON::ParserError => error
      raise ArgumentError, "invalid plugin manifest: #{error.message}"
    end

    def validate_manifest!(manifest)
      unless manifest.is_a?(Hash) && manifest["schemaVersion"] == 1
        raise ArgumentError, "plugin manifest must use schemaVersion 1"
      end
      REQUIRED_MANIFEST_STRINGS.each do |field|
        value = manifest[field]
        unless value.is_a?(String) && !value.strip.empty?
          raise ArgumentError, "plugin manifest needs a non-empty #{field}"
        end
      end
      plugin_id = manifest.fetch("id")
      raise ArgumentError, "invalid plugin id" unless VALID_ID.match?(plugin_id)
      if plugin_id.start_with?("omarchy.")
        raise ArgumentError, "plugin id uses the reserved omarchy.* namespace"
      end

      entry_points = manifest["entryPoints"]
      unless entry_points.is_a?(Hash) && !entry_points.empty?
        raise ArgumentError, "plugin manifest needs entryPoints"
      end
      files = entry_points.values
      unless files.all? { |file| file.is_a?(String) } && files.uniq.length == files.length
        raise ArgumentError, "plugin manifest entryPoints must be unique file names"
      end
      unsupported = files - QmlCompiler::ENTRY_TYPES.keys
      unless unsupported.empty?
        raise ArgumentError, "unsupported plugin entryPoints: #{unsupported.join(', ')}"
      end
    end

    def validate_readme!(manifest)
      name = Dir.children(@path).find { |entry| README_PATTERN.match?(entry) }
      readme = File.read(File.join(@path, name))
      raise ArgumentError, "plugin README needs installation instructions" unless readme.match?(/install/i)
      unless readme.match?(/(?:remove|uninstall)/i)
        raise ArgumentError, "plugin README needs removal instructions"
      end
      unless readme.include?("omarchy plugin add")
        raise ArgumentError, "plugin README needs an omarchy plugin add command"
      end
      unless readme.include?("omarchy plugin remove #{manifest.fetch('id')}")
        raise ArgumentError, "plugin README removal command must use the manifest id"
      end
    end

    def validate_runtime!
      runtime = File.join(@path, "omarchy-ui-runtime")
      unless File.file?(runtime) && File.executable?(runtime) && !File.symlink?(runtime)
        raise ArgumentError, "plugin package needs an executable omarchy-ui-runtime"
      end
    end

    def validate_ruby_surface!
      entrypoint = File.join(@path, "main.rb")
      unless File.file?(entrypoint) && !File.symlink?(entrypoint)
        raise ArgumentError, "plugin package needs one bundled main.rb"
      end

      ruby_files = Dir.glob(File.join(@path, "**", "*.rb"), File::FNM_DOTMATCH)
        .select { |path| File.file?(path) }
        .map { |path| path.delete_prefix("#{@path}/") }
        .sort
      unless ruby_files == ["main.rb"]
        raise ArgumentError, "plugin package may contain only the bundled main.rb Ruby program"
      end
    end

    def validate_qml_surface!(manifest)
      expected = manifest.fetch("entryPoints").values.sort
      qml_files = Dir.glob(File.join(@path, "**", "*.qml"), File::FNM_DOTMATCH)
        .select { |path| File.file?(path) }
        .map { |path| path.delete_prefix("#{@path}/") }
        .sort
      unless qml_files == expected
        raise ArgumentError, "plugin package may contain only manifest-declared generated QML shims"
      end
    end
  end
end
