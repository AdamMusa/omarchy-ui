# frozen_string_literal: true

require_relative "omarchy_ui/protocol"
require_relative "omarchy_ui/value"
require_relative "omarchy_ui/state_store"
require_relative "omarchy_ui/node"
require_relative "omarchy_ui/animation"
require_relative "omarchy_ui/scheduler"
require_relative "omarchy_ui/component_registry"
require_relative "omarchy_ui/components"
require_relative "omarchy_ui/builder"
require_relative "omarchy_ui/application"

module OmarchyUI
  VERSION = "0.3.0"

  def self.plugin(&definition)
    Application.new(&definition).run
  end

  class << self
    alias application plugin
    alias app plugin
  end
end
