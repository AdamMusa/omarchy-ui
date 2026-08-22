# frozen_string_literal: true

module OmarchyUI
  COMPONENTS = {
    container: [%i[spacing padding bordered visible], [], true],
    row: [%i[spacing alignment visible], [], true],
    column: [%i[spacing alignment visible], [], true],
    grid: [%i[columns rows spacing row_spacing column_spacing visible], [], true],
    stack: [%i[visible], [], true],
    scroll: [%i[width height clip visible], [], true],
    rectangle: [%i[width height color radius border_color border_width padding visible], [], true],
    text: [%i[text style size bold color wrap width visible], [], false],
    icon: [%i[name text size color visible], [], false],
    image: [%i[source width height fill_mode visible], [], false],
    spacer: [%i[width height visible], [], false],
    button: [%i[text icon tooltip enabled selected bordered visible], %i[click], false],
    action_button: [%i[icon tooltip enabled bordered size visible], %i[click], false],
    toggle: [%i[label description checked enabled visible], %i[change], false],
    toggle_switch: [%i[checked busy enabled visible], %i[change], false],
    text_field: [%i[text placeholder password enabled width visible], %i[change submit focus blur], false],
    number_field: [%i[label value from to step enabled visible], %i[change], false],
    slider: [%i[value minimum maximum step integer ticks enabled width visible], %i[change], false],
    dropdown: [%i[label value options placeholder enabled width visible], %i[change], false],
    multi_select: [%i[label values options placeholder enabled width visible], %i[change], false],
    button_group: [%i[value options enabled visible], %i[change], false],
    progress: [%i[value minimum maximum width height color visible], [], false],
    separator: [%i[strength visible], [], false],
    section_header: [%i[text visible], [], false]
  }.freeze

  DEFAULT_COMPONENTS = ComponentRegistry.new
  COMPONENTS.each do |name, (properties, events, container)|
    adapter = name.to_s.split("_").map(&:capitalize).join + ".qml"
    DEFAULT_COMPONENTS.register(name, qml: adapter, properties:, events:, container:)
  end
end
