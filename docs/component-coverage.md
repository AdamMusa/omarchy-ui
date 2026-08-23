# Built-in component coverage

Omarchy UI aims to provide a specific Ruby API for the application controls developers expect from
a complete UI framework. A custom `register_component` adapter does not count as built-in coverage.

Each completed component must include a registry schema, named Ruby builder method, native QML
renderer, reactive property support, applicable events, tests, and reference documentation.

## Scope

This catalog targets public, application-facing types from Qt Quick, Qt Quick Controls, Qt Quick
Layouts, Qt Quick Dialogs, Qt Quick Effects, Qt Quick Shapes, and Qt Multimedia, plus useful
Omarchy-native controls and charts. Private `impl` types, style implementations, abstract base
classes, QML compiler infrastructure, compositor protocols, and operating-system service objects
are not widgets and are intentionally excluded. Framework concepts such as state, timers,
transitions, and animation groups receive Ruby APIs even though they are not visual widgets.

## Foundation and layout

- [x] container
- [x] row
- [x] column
- [x] grid
- [x] row_layout
- [x] column_layout
- [x] grid_layout
- [x] flow
- [x] stack
- [x] center
- [x] card
- [x] scroll
- [x] rectangle
- [x] border_overlay
- [x] aspect_ratio
- [x] constrained_box
- [x] fitted_box
- [x] wrap
- [x] split_view
- [x] stack_layout
- [ ] layout_item_proxy
- [x] loader
- [x] flickable
- [x] focus_scope
- [x] flipable
- [x] border_image
- [ ] window
- [ ] application_window

## Display, content, and media

- [x] text
- [x] icon
- [x] image
- [x] spacer
- [x] separator
- [x] section_header
- [x] panel_hero
- [x] optical_glyph
- [x] tooltip
- [x] label
- [x] rich_text
- [x] selectable_text
- [x] animated_image
- [x] video
- [x] audio
- [x] avatar
- [x] badge
- [x] chip
- [x] divider
- [x] markdown
- [ ] web_view
- [x] vector_image
- [x] font_loader
- [x] text_metrics

## Buttons and input

- [x] button
- [x] action_button
- [x] bar_icon_button
- [x] bar_indicator
- [x] widget_button
- [x] checkbox
- [x] toggle
- [x] toggle_switch
- [x] text_field
- [x] number_field
- [x] slider
- [x] dropdown
- [x] searchable_dropdown
- [x] multi_select
- [x] button_group
- [x] round_button
- [x] tool_button
- [x] delay_button
- [x] radio_button
- [x] radio_group
- [x] text_area
- [x] search_field
- [x] password_field
- [x] range_slider
- [x] dial
- [x] spin_box
- [ ] color_picker
- [ ] date_picker
- [ ] time_picker
- [ ] file_picker
- [ ] folder_picker
- [ ] font_picker
- [ ] double_spin_box
- [ ] dialog_button_box
- [ ] action
- [ ] action_group

## Navigation and structure

- [x] list_view
- [x] key_catcher
- [ ] page
- [ ] pane
- [ ] frame
- [ ] group_box
- [ ] tabs
- [ ] tab_bar
- [ ] tab_button
- [ ] page_indicator
- [ ] stack_view
- [ ] swipe_view
- [ ] drawer
- [ ] navigation_rail
- [ ] breadcrumb
- [ ] pagination
- [ ] expansion_panel
- [ ] accordion
- [ ] tool_bar
- [ ] tool_separator

## Menus, dialogs, and feedback

- [x] confirm_dialog
- [x] progress
- [ ] menu
- [ ] menu_item
- [ ] menu_separator
- [ ] menu_bar
- [ ] context_menu
- [ ] popup
- [ ] dialog
- [ ] alert_dialog
- [ ] message_dialog
- [ ] bottom_sheet
- [ ] modal_sheet
- [ ] snackbar
- [ ] banner
- [ ] toast
- [ ] busy_indicator
- [ ] progress_ring
- [ ] skeleton

## Data and collections

- [ ] item_delegate
- [ ] check_delegate
- [ ] radio_delegate
- [ ] switch_delegate
- [ ] swipe_delegate
- [ ] grid_view
- [ ] table_view
- [ ] tree_view
- [ ] data_table
- [ ] horizontal_header
- [ ] vertical_header
- [ ] table_view_delegate
- [ ] tree_view_delegate
- [ ] horizontal_header_delegate
- [ ] vertical_header_delegate
- [ ] reorderable_list
- [ ] carousel
- [ ] calendar
- [ ] month_grid
- [ ] week_number_column
- [ ] day_of_week_row
- [ ] tumbler

## Charts and visualization

- [x] line_chart
- [x] area_chart
- [x] bar_chart
- [ ] stacked_bar_chart
- [ ] pie_chart
- [ ] donut_chart
- [ ] scatter_chart
- [ ] bubble_chart
- [ ] radar_chart
- [ ] heatmap
- [ ] sparkline
- [ ] gauge
- [ ] radial_gauge
- [ ] histogram
- [ ] candlestick_chart
- [ ] legend

## Drawing and interaction

- [ ] canvas
- [ ] shape
- [ ] line
- [ ] path
- [ ] circle
- [ ] gradient
- [ ] drag_area
- [ ] drop_area
- [ ] pinch_area
- [ ] hover_area
- [ ] selection_rectangle
- [ ] scroll_bar
- [ ] scroll_indicator

## Animation, state, and timing

- [ ] animation
- [ ] number_animation
- [ ] color_animation
- [ ] rotation_animation
- [ ] vector_animation
- [ ] path_animation
- [ ] property_animation
- [ ] pause_animation
- [ ] script_action
- [ ] property_action
- [ ] parallel_animation
- [ ] sequential_animation
- [ ] spring_animation
- [ ] smoothed_animation
- [ ] anchor_animation
- [ ] parent_animation
- [ ] opacity_animator
- [ ] rotation_animator
- [ ] scale_animator
- [ ] x_animator
- [ ] y_animator
- [ ] uniform_animator
- [ ] frame_animation
- [ ] animation_controller
- [ ] behavior
- [ ] transition
- [ ] state
- [ ] state_group
- [ ] property_changes
- [ ] anchor_changes
- [ ] parent_change
- [ ] timer

## Effects

- [ ] multi_effect
- [ ] rectangular_shadow
- [ ] opacity_mask
- [ ] blur
- [ ] drop_shadow
- [ ] colorize
- [ ] glow

## Multimedia and capture

- [ ] media_player
- [ ] video_output
- [ ] sound_effect
- [ ] camera
- [ ] capture_session
- [ ] image_capture
- [ ] media_recorder
- [ ] audio_input
- [ ] audio_output
- [ ] media_devices
- [ ] screen_capture
- [ ] window_capture

## Models and utilities

- [ ] list_model
- [ ] delegate_model
- [ ] delegate_model_group
- [ ] sort_filter_proxy_model
- [ ] folder_list_model
- [ ] settings
- [ ] standard_paths
- [ ] clipboard
