# frozen_string_literal: true

module OmarchyUI
  ICON_NAMES = %i[
    ruby phone plus minus reset refresh house gear search xmark check menu user bell wifi bluetooth
    volume_high volume_low volume_off play pause stop trash edit folder file download upload link lock
    unlock eye eye_slash star heart info warning circle_info circle_check circle_xmark arrow_left
    arrow_right arrow_up arrow_down chevron_left chevron_right chevron_up chevron_down calendar clock
    camera image music terminal code copy save power globe location pin android apple
  ].freeze

  COMPONENTS = {
    container: [%i[spacing padding bordered visible], %i[click], true],
    row: [%i[spacing alignment visible], %i[click], true],
    column: [%i[spacing alignment visible], %i[click], true],
    grid: [%i[columns rows spacing row_spacing column_spacing visible], %i[click], true],
    row_layout: [%i[spacing alignment visible], %i[click], true],
    column_layout: [%i[spacing alignment visible], %i[click], true],
    grid_layout: [%i[columns rows spacing row_spacing column_spacing alignment visible], %i[click], true],
    flow: [%i[spacing orientation width height visible], %i[click], true],
    center: [%i[padding spacing visible], %i[click], true],
    card: [%i[padding spacing color radius border_color accent visible], %i[click], true],
    stack: [%i[visible], %i[click], true],
    scroll: [%i[width height clip visible], %i[click], true],
    rectangle: [%i[width height color radius border_color border_width padding visible], %i[click], true],
    border_overlay: [%i[color width_spec gradient_colors gradient_angle radius visible], [], false],
    aspect_ratio: [%i[ratio width height clip visible], %i[click], true],
    constrained_box: [%i[width height min_width min_height max_width max_height clip visible], %i[click], true],
    fitted_box: [%i[width height fit alignment clip visible], %i[click], true],
    wrap: [%i[width height spacing orientation layout_direction visible], %i[click], true],
    split_view: [%i[width height orientation visible], %i[click resize], true],
    stack_layout: [%i[current_index width height visible], %i[click change], true],
    loader: [%i[active asynchronous width height visible], %i[click loaded status], true],
    flickable: [%i[width height content_width content_height direction bounds_behavior interactive clip visible], %i[click scroll flick_start flick_end], true],
    focus_scope: [%i[focus active_focus width height visible], %i[click focus blur], true],
    flipable: [%i[flipped axis duration easing interactive width height visible], %i[click change], true],
    border_image: [%i[source width height border_left border_top border_right border_bottom horizontal_tile vertical_tile asynchronous cache mirror smooth visible], %i[click loaded error status], true],
    text: [%i[text style size bold color wrap width visible], [], false],
    label: [%i[text color size bold width wrap elide horizontal_alignment vertical_alignment maximum_lines format visible], %i[link], false],
    rich_text: [%i[text color link_color size bold width wrap maximum_lines visible], %i[link], false],
    selectable_text: [%i[text color selection_color selected_text_color size bold width wrap format visible], %i[selection link], false],
    icon: [%i[name text size color visible], [], false],
    tooltip: [%i[text delay timeout foreground background border font_family font_size visible], [], false],
    image: [%i[source width height fill_mode visible], [], false],
    spacer: [%i[width height visible], [], false],
    button: [%i[text icon tooltip selected active cursor focusable bordered foreground background accent font_family font_size icon_size icon_rotation icon_spinning horizontal_padding vertical_padding left_align tooltip_background tooltip_foreground tooltip_border], %i[click right_click hover], false],
    action_button: [%i[icon tooltip foreground hover_color font_family font_size size focusable cursor bordered], %i[click hover], false],
    bar_icon_button: [%i[icon tooltip active foreground active_color slot_size optical_size font_family font_size text_rotation keep_space dimmed concealed interactive], %i[click right_click middle_click wheel], false],
    bar_indicator: [%i[active active_icon inactive_icon active_tooltip inactive_tooltip indicator_block foreground active_color font_family font_size], %i[click right_click middle_click wheel], false],
    toggle: [%i[label description checked cursor rounded foreground accent font_family title_size description_size], %i[change hover], false],
    checkbox: [%i[label checked foreground accent background font_family font_size indicator_size spacing cursor], %i[change hover], false],
    toggle_switch: [%i[checked busy interactive cursor cursor_ring cursor_pad rounded foreground accent track_height track_width knob_size knob_inset], %i[change hover], false],
    text_field: [%i[text placeholder password foreground accent selection_tint horizontal_padding vertical_padding cursor], %i[change submit focus blur input], false],
    number_field: [%i[label value from to step foreground accent font_family font_size field_width cursor], %i[change hover], false],
    slider: [%i[value minimum maximum step integer track_color fill_color knob_color track_height knob_size ticks tick_color], %i[input change right_click], false],
    dropdown: [%i[label value options foreground background popup_border accent font_family row_height popup_row_height show_label cursor], %i[change hover], false],
    searchable_dropdown: [%i[label value options placeholder empty_text trigger_label foreground background popup_border accent font_family row_height popup_row_height popup_min_height show_label cursor], %i[change hover], false],
    multi_select: [%i[label values options options_command options_command_cwd placeholder empty_text no_selection_text trigger_label show_label foreground background popup_border accent font_family row_height popup_row_height popup_min_height cursor], %i[change hover], false],
    button_group: [%i[value options foreground background accent font_family font_size focusable cursor_index], %i[change hover], false],
    progress: [%i[value minimum maximum width height color visible], [], false],
    line_chart: [%i[values labels width height color fill_color grid_color line_width minimum maximum show_grid show_points point_size visible], %i[select hover], false],
    area_chart: [%i[values labels width height color fill_color grid_color line_width minimum maximum show_grid visible], %i[select hover], false],
    bar_chart: [%i[values labels width height colors grid_color minimum maximum show_grid bar_spacing visible], %i[select hover], false],
    separator: [%i[strength visible], [], false],
    section_header: [%i[text visible], [], false],
    confirm_dialog: [%i[opened message cancel_text confirm_text selected_index background foreground scrim selected_background selected_text font_family corner_radius], %i[cancel confirm], false],
    panel_hero: [%i[title meta detail foreground font_family icon_size icon_opacity meta_opacity], [], false],
    optical_glyph: [%i[text size color debug_bounds visible], [], false],
    cursor_surface: [%i[cursor current outline bordered foreground accent fill current_fill], %i[click], true],
    widget_button: [%i[text font_family font_size foreground active_color active horizontal_margin vertical_padding fixed_width fixed_height text_rotation keep_space dimmed concealed interactive pressable use_active_color maintain_indicator_reveal label_visible has_visual_content tooltip], %i[click right_click middle_click wheel], false],
    list_view: [%i[items key_field label_field description_field icon_field selected orientation spacing width height empty_text visible], %i[activate change scroll], false],
    key_catcher: [%i[blocked visible], %i[move activate return close delete tab text], true]
  }.freeze

  DEFAULT_COMPONENTS = ComponentRegistry.new
  COMPONENTS.each do |name, (properties, events, container)|
    adapter = name.to_s.split("_").map(&:capitalize).join + ".qml"
    DEFAULT_COMPONENTS.register(name, qml: adapter, properties:, events:, container:)
  end
end
