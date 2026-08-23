# Built-in component coverage

Omarchy UI aims to provide a specific Ruby API for the application controls developers expect from
a complete UI framework. A custom `register_component` adapter does not count as built-in coverage.

Each completed component must include a registry schema, named Ruby builder method, native QML
renderer, reactive property support, applicable events, tests, and reference documentation.

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
- [ ] aspect_ratio
- [ ] constrained_box
- [ ] fitted_box
- [ ] wrap
- [ ] split_view
- [ ] stack_layout
- [ ] layout_item_proxy

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
- [ ] label
- [ ] rich_text
- [ ] selectable_text
- [ ] animated_image
- [ ] video
- [ ] audio
- [ ] avatar
- [ ] badge
- [ ] chip
- [ ] divider
- [ ] markdown
- [ ] web_view

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
- [ ] round_button
- [ ] tool_button
- [ ] delay_button
- [ ] radio_button
- [ ] radio_group
- [ ] text_area
- [ ] search_field
- [ ] password_field
- [ ] range_slider
- [ ] dial
- [ ] spin_box
- [ ] color_picker
- [ ] date_picker
- [ ] time_picker
- [ ] file_picker
- [ ] folder_picker
- [ ] font_picker

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
- [ ] reorderable_list
- [ ] carousel
- [ ] calendar
- [ ] month_grid
- [ ] week_number_column
- [ ] day_of_week_row
- [ ] tumbler

## Charts and visualization

- [x] line_chart
- [ ] area_chart
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
