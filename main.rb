# frozen_string_literal: true

require_relative "lib/omarchy_ui"

OmarchyUI.plugin do
  state :count, 0

  bar_widget do
    row spacing: 6 do
      icon "ruby"
      text "Ruby UI"
    end

    on_click { open_panel :counter }
  end

  panel :counter do
    column spacing: 12 do
      text "Ruby → QML → Omarchy", style: :heading
      text(id: :count) { "Count: #{state.count}" }

      dynamic id: :parity, spacing: 4 do
        text(state.count.even? ? "Even" : "Odd", id: :parity_label, style: :caption)
        icon(state.count.even? ? :reset : :plus, id: :parity_icon)
      end

      row spacing: 8 do
        button "Increment", id: :increment do
          state.count += 1
        end

        button "Reset", id: :reset do
          state.count = 0
        end
      end
    end
  end
end
