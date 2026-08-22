# frozen_string_literal: true

module OmarchyUI
  def self.plugin(&definition)
    Application.new(&definition).run
  end

  def self.application(&definition)
    plugin(&definition)
  end

  def self.app(&definition)
    plugin(&definition)
  end
end
