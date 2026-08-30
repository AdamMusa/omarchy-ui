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
catalog = JSON.generate(Zui::DEFAULT_COMPONENTS.protocol_schema)
raise "component catalog exceeds Quickshell transport budget" unless catalog.bytesize < 131_072
raise "identity property maps were not compacted" if Zui::DEFAULT_COMPONENTS.fetch(:button).to_h.key?("property_map")

puts "omarchy-ui-runtime adapter: OK"
