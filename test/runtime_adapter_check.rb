# frozen_string_literal: true

application = Zui::Application.new do
  app(:main) { text "Shared Zui application" }
end

class << application
  def run
    :omarchy_adapter_ok
  end
end

SharedZuiApplication = application

module SharedZuiApplicationModule
  def self.build
    SharedZuiApplication
  end
end

raise "application instance was not adapted" unless OmarchyUI.run(application) == :omarchy_adapter_ok
raise "application module was not adapted" unless OmarchyUI.run(SharedZuiApplicationModule) == :omarchy_adapter_ok

puts "omarchy-ui-runtime adapter: OK"
