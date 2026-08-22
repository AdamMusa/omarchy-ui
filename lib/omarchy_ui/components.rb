# frozen_string_literal: true

module OmarchyUI
  COMPONENTS = {
    container: [%i[spacing padding bordered visible], %i[click], true],
    row: [%i[spacing alignment visible], %i[click], true],
    column: [%i[spacing alignment visible], %i[click], true],
    grid: [%i[columns rows spacing row_spacing column_spacing visible], %i[click], true],
    stack: [%i[visible], %i[click], true],
    scroll: [%i[width height clip visible], %i[click], true],
    rectangle: [%i[width height color radius border_color border_width padding visible], %i[click], true],
    text: [%i[text style size bold color wrap width visible], [], false],
    icon: [%i[name text size color visible], [], false],
    image: [%i[source width height fill_mode visible], [], false],
    spacer: [%i[width height visible], [], false],
    button: [%i[text icon tooltip enabled selected bordered visible], %i[click right_click hover], false],
    action_button: [%i[icon tooltip enabled bordered size visible], %i[click hover], false],
    toggle: [%i[label description checked enabled visible], %i[change hover], false],
    toggle_switch: [%i[checked busy enabled visible], %i[change hover], false],
    text_field: [%i[text placeholder password enabled width visible], %i[change submit focus blur], false],
    number_field: [%i[label value from to step enabled visible], %i[change], false],
    slider: [%i[value minimum maximum step integer ticks enabled width visible], %i[input change right_click], false],
    dropdown: [%i[label value options placeholder enabled width visible], %i[change hover], false],
    searchable_dropdown: [%i[label value options placeholder empty_text trigger_label enabled width visible], %i[change hover], false],
    multi_select: [%i[label values options placeholder empty_text no_selection_text trigger_label enabled width visible], %i[change hover], false],
    button_group: [%i[value options enabled visible], %i[change hover], false],
    progress: [%i[value minimum maximum width height color visible], [], false],
    separator: [%i[strength visible], [], false],
    section_header: [%i[text visible], [], false],
    confirm_dialog: [%i[opened message cancel_text confirm_text selected_index visible], %i[cancel confirm], false],
    panel_hero: [%i[title meta detail icon_size icon_opacity visible], [], false],
    optical_glyph: [%i[text size color debug_bounds visible], [], false],
    cursor_surface: [%i[width height current outline bordered color visible], %i[click], true],
    widget_button: [%i[text tooltip active dimmed concealed interactive pressable width height rotation visible], %i[click right_click middle_click wheel], false],
    list_view: [%i[items key_field label_field description_field icon_field selected orientation spacing width height empty_text visible], %i[activate change scroll], false]
  }.freeze

  DEFAULT_COMPONENTS = ComponentRegistry.new
  COMPONENTS.each do |name, (properties, events, container)|
    adapter = name.to_s.split("_").map(&:capitalize).join + ".qml"
    DEFAULT_COMPONENTS.register(name, qml: adapter, properties:, events:, container:)
  end
end
