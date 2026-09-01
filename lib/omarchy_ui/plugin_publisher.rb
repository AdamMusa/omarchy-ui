# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "tmpdir"

module OmarchyUI
  class PluginPublisher
    MARKETPLACE_REPOSITORY = "omacom/omarchy-plugin-marketplace"
    CATEGORIES = [
      "Appearance", "Desktop", "Developer Tools", "Hardware", "Kids", "Productivity", "System", "Widgets", "Other"
    ].freeze
    TAGS = %w[
      ai bar education games hyprland kids launcher media power-management quickshell security system workspaces
    ].freeze
    REPOSITORY = /\A[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\z/

    def self.publish!(**arguments)
      new(**arguments).publish!
    end

    def initialize(package:, source:, repository:, category:, tags:, create: false, submit: false,
                   marketplace_repository: ENV.fetch("OMARCHY_UI_MARKETPLACE_REPOSITORY", MARKETPLACE_REPOSITORY),
                   out: $stdout)
      @package = File.expand_path(package)
      @source = File.expand_path(source)
      @repository = repository.to_s.strip
      @category = category.to_s.strip
      @tags = Array(tags).map(&:to_s).map(&:strip).reject(&:empty?).uniq
      @create = create
      @submit = submit
      @marketplace_repository = marketplace_repository.to_s.strip
      @out = out
    end

    def publish!
      validate_options!
      manifest = PluginPackage.validate!(@package)
      validate_install_url!
      ensure_distinct_repository!
      ensure_gh_authenticated!
      ensure_distribution_repository!(manifest)
      commit = publish_package!(manifest)
      title = "[Plugin]: #{manifest.fetch('name')}"
      body = submission_body(commit:)
      show_submission(title, body)
      if @submit
        issue_url = submit_to_marketplace!(title, body)
        @out.puts("Marketplace submission: #{issue_url}")
      else
        @out.puts("Review the submission above, then rerun with --submit to create or refresh it.")
      end
      @out.puts("Published #{@repository} at #{commit}")
      commit
    end

    private

    def validate_options!
      raise ArgumentError, "publish requires --repo OWNER/REPOSITORY" unless REPOSITORY.match?(@repository)
      raise ArgumentError, "invalid marketplace repository" unless REPOSITORY.match?(@marketplace_repository)
      unless CATEGORIES.include?(@category)
        raise ArgumentError, "publish category must be one of: #{CATEGORIES.join(', ')}"
      end
      unless (1..3).cover?(@tags.length) && (@tags - TAGS).empty?
        raise ArgumentError, "publish needs one to three allowed tags: #{TAGS.join(', ')}"
      end
    end

    def ensure_distinct_repository!
      output, _error, status = capture("git", "-C", @source, "remote", "get-url", "origin")
      return unless status.success?

      source_repository = github_repository(output.strip)
      if source_repository&.casecmp?(@repository)
        raise ArgumentError,
          "publish target must be a separate distribution repository; refusing to replace the source repository"
      end
    end

    def validate_install_url!
      readme_name = Dir.children(@package).find { |entry| PluginPackage::README_PATTERN.match?(entry) }
      readme = File.read(File.join(@package, readme_name))
      repository_url = "https://github.com/#{@repository}"
      return if readme.downcase.include?(repository_url.downcase)

      raise ArgumentError,
        "plugin README install command must use the distribution repository #{repository_url}"
    end

    def ensure_gh_authenticated!
      _output, error, status = capture("gh", "auth", "status")
      return if status.success?

      detail = error.strip.lines.last.to_s.strip
      raise ArgumentError, "GitHub CLI authentication is required#{detail.empty? ? '' : ": #{detail}"}"
    rescue Errno::ENOENT
      raise ArgumentError, "publish requires the GitHub CLI (gh)"
    end

    def ensure_distribution_repository!(manifest)
      output, error, status = capture(
        "gh", "repo", "view", @repository,
        "--json", "nameWithOwner,visibility", "--jq", "[.nameWithOwner,.visibility] | @tsv"
      )
      unless status.success?
        unless @create
          raise ArgumentError,
            "distribution repository #{@repository} was not found; create it first or rerun with --create"
        end
        run!(
          "gh", "repo", "create", @repository, "--public",
          "--description", "#{manifest.fetch('name')} — an Omarchy plugin built entirely in Ruby"
        )
        output, error, status = capture(
          "gh", "repo", "view", @repository,
          "--json", "nameWithOwner,visibility", "--jq", "[.nameWithOwner,.visibility] | @tsv"
        )
      end
      unless status.success?
        raise ArgumentError, "could not inspect distribution repository: #{error.strip}"
      end

      _name, visibility = output.strip.split("\t", 2)
      raise ArgumentError, "distribution repository must be public" unless visibility == "PUBLIC"
    end

    def publish_package!(manifest)
      Dir.mktmpdir("omarchy-ui-publish-") do |temporary|
        checkout = File.join(temporary, "repository")
        run!("gh", "repo", "clone", @repository, checkout, "--", "--quiet")
        guard_existing_package!(checkout, manifest)
        replace_checkout!(checkout)
        run!("git", "-C", checkout, "add", "-A")
        _output, _error, clean = capture("git", "-C", checkout, "diff", "--cached", "--quiet")
        unless clean.success?
          run!(
            "git", "-C", checkout, "commit", "-m",
            "Publish #{manifest.fetch('name')} #{manifest.fetch('version')}"
          )
          run!("git", "-C", checkout, "push", "origin", "HEAD")
        end
        output, _error, _status = capture("git", "-C", checkout, "rev-parse", "HEAD")
        output.strip
      end
    end

    def guard_existing_package!(checkout, manifest)
      entries = Dir.children(checkout) - [".git"]
      return if entries.empty?

      existing_manifest = File.join(checkout, "manifest.json")
      unless File.file?(existing_manifest)
        raise ArgumentError, "distribution repository is not empty and has no root manifest.json"
      end
      existing_id = JSON.parse(File.read(existing_manifest)).fetch("id")
      return if existing_id == manifest.fetch("id")

      raise ArgumentError,
        "distribution repository contains plugin #{existing_id.inspect}, not #{manifest.fetch('id').inspect}"
    rescue JSON::ParserError, KeyError => error
      raise ArgumentError, "distribution repository has an invalid manifest: #{error.message}"
    end

    def replace_checkout!(checkout)
      (Dir.children(checkout) - [".git"]).each do |entry|
        FileUtils.remove_entry(File.join(checkout, entry))
      end
      Dir.children(@package).each do |entry|
        FileUtils.cp_r(File.join(@package, entry), File.join(checkout, entry), preserve: true)
      end
    end

    def submission_body(commit:)
      <<~MARKDOWN
        ### Repository URL

        https://github.com/#{@repository}

        ### Category

        #{@category}

        ### Tags

        #{@tags.join(', ')}

        ### Suggest a missing tag

        _No response_

        ### Maintainer notes

        Built and published by Omarchy UI as a thin Ruby-authored package. Current review target: `#{commit}`.

        ### Submission checklist

        - [x] The repository is public and contains installation and removal instructions.
        - [x] I have documented the plugin license and any external dependencies.
        - [x] I confirm that I own or have permission to submit this plugin and its preview assets.
        - [x] The plugin does not overwrite user configuration without explicit consent.
        - [x] I understand that approval is for listing and is not a security review.
      MARKDOWN
    end

    def show_submission(title, body)
      @out.puts("Marketplace issue preview (#{@marketplace_repository}):")
      @out.puts(title)
      @out.puts(body)
    end

    def submit_to_marketplace!(title, body)
      output, error, status = capture(
        "gh", "issue", "list", "--repo", @marketplace_repository, "--state", "all", "--limit", "1000",
        "--json", "number,body,state,url"
      )
      raise ArgumentError, "could not inspect marketplace submissions: #{error.strip}" unless status.success?

      repository_url = "https://github.com/#{@repository}"
      matching = JSON.parse(output).select { |issue| issue.fetch("body", "").include?(repository_url) }
      open_issue = matching.find { |issue| issue.fetch("state") == "OPEN" }
      if open_issue
        run!(
          "gh", "issue", "edit", open_issue.fetch("number").to_s,
          "--repo", @marketplace_repository, "--title", title, "--body", body
        )
        return open_issue.fetch("url")
      end
      if matching.any?
        raise ArgumentError,
          "this repository already has a closed marketplace submission; use the marketplace verification/update form"
      end

      created, create_error, create_status = capture(
        "gh", "issue", "create", "--repo", @marketplace_repository, "--title", title, "--body", body
      )
      raise ArgumentError, "marketplace submission failed: #{create_error.strip}" unless create_status.success?

      created.lines.map(&:strip).find { |line| line.start_with?("https://") } || created.strip
    rescue JSON::ParserError, KeyError => error
      raise ArgumentError, "invalid marketplace response: #{error.message}"
    end

    def github_repository(url)
      value = url.to_s.strip.sub(/\.git\z/, "")
      match = value.match(%r{(?:github\.com[/:])([^/]+/[^/]+)\z}i)
      match && match[1]
    end

    def capture(*command)
      Open3.capture3(*command)
    end

    def run!(*command)
      output, error, status = capture(*command)
      return output if status.success?

      detail = [output, error].join("\n").strip
      raise ArgumentError, "command failed: #{command.first}#{detail.empty? ? '' : ": #{detail}"}"
    end
  end
end
