# frozen_string_literal: true

module Zui
  def self.app(&definition)
    Application.new(&definition).run
  end

  def self.application(&definition)
    app(&definition)
  end
end

module OmarchyUI
  def self.run(application = nil, ui: nil, &definition)
    if application && (ui || definition)
      raise ArgumentError, "pass a Zui application or a definition, not both"
    end

    instance = if application.nil?
      Application.new(ui: ui, &definition)
    elsif application.is_a?(Application)
      application
    elsif application.respond_to?(:build)
      application.build
    else
      raise ArgumentError, "expected a Zui::Application or an application module responding to build"
    end

    unless instance.is_a?(Application)
      raise ArgumentError, "application module did not build a Zui::Application"
    end

    instance.run
  end

  def self.plugin(ui: nil, &definition)
    run(nil, ui: ui, &definition)
  end

  def self.application(ui: nil, &definition)
    run(nil, ui: ui, &definition)
  end

  def self.app(ui: nil, &definition)
    run(nil, ui: ui, &definition)
  end
end
