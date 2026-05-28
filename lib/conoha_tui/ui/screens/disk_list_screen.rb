# frozen_string_literal: true

module ConohaTui
  module Ui
    module Screens
      # 追加ディスク一覧画面。
      # ディスクと接続 VPS をツリー形式で表示する。
      class DiskListScreen < BaseScreen
        def initialize(tui, services)
          super
          @disks        = []
          @vpses        = []
          @selected_idx = 0
          @expanded     = {}
        end

        def on_activate
          @disks        = @services[:disk].list
          @vpses        = @services[:vps].list
          @selected_idx = 0
          @expanded     = {}
        end

        def render(frame, area = frame.area)
          help_area, content_area, status_area = build_layout(area)
          render_chrome(frame, help_area, status_area)
          frame.render_widget(render_tree, content_area)
        end

        def handle_input(event)
          items = build_tree_items
          case event
          in { type: :key, code: "q" } | { type: :key, code: "c", modifiers: ["ctrl"] }
            :quit
          in type: :key, code: "down" | "j"
            @selected_idx = [[@selected_idx + 1, 0].max, [items.size - 1, 0].max].min
          in type: :key, code: "up" | "k"
            @selected_idx = [@selected_idx - 1, 0].max
          in type: :key, code: "enter" | "space"
            toggle_expand(items)
          in type: :key, code: "r"
            refresh_disks
          else
            nil
          end
        end

        private

        def setup_hints
          @help_bar.set_hints([
            ["↑/↓", "移動"],
            ["Enter/Sp", "展開/折畳"],
            ["r", "更新"],
            ["q", "終了"]
          ])
        end

        def build_tree_items
          items = []
          @disks.each do |disk|
            items << { type: :disk, object: disk, depth: 0, key: disk.id }
            next unless @expanded[disk.id]

            disk.attached_server_ids.each do |server_id|
              vps   = @vpses.find { |v| v.id == server_id }
              label = vps ? "#{vps.name} (#{vps.status})" : "ID: #{server_id[0..7]}…"
              items << { type: :vps, label: label, depth: 1, key: "#{disk.id}-#{server_id}" }
            end
          end
          items
        end

        def render_tree
          items = build_tree_items
          list_items = items.map do |item|
            case item[:type]
            when :disk
              expanded   = @expanded[item[:object].id]
              has_attach = item[:object].attached?
              icon       = has_attach ? (expanded ? "▼ " : "▶ ") : "  "
              status_style = item[:object].attached? ? @tui.style(fg: :green) : @tui.style(fg: :dark_gray)

              @tui.list_item(
                content: @tui.text_line(spans: [
                  @tui.text_span(content: icon, style: @tui.style(fg: :yellow)),
                  @tui.text_span(content: item[:object].name.to_s.then { |n| n.empty? ? "(名前なし)" : n },
                                 style: @tui.style(modifiers: [:bold])),
                  @tui.text_span(content: " #{item[:object].size_display}",
                                 style: @tui.style(fg: :cyan)),
                  @tui.text_span(content: " #{item[:object].status}",
                                 style: status_style)
                ])
              )
            when :vps
              @tui.list_item(
                content: @tui.text_line(spans: [
                  @tui.text_span(content: "    └─ ", style: @tui.style(fg: :dark_gray)),
                  @tui.text_span(content: item[:label].to_s)
                ])
              )
            end
          end

          @tui.list(
            items:             list_items,
            selected_index:    @selected_idx,
            highlight_style:   @tui.style(fg: :yellow, modifiers: [:bold]),
            highlight_symbol:  "",
            highlight_spacing: :when_selected,
            block:             @tui.block(
              title: "追加ディスク一覧 (#{@disks.size}件)",
              borders: :all
            )
          )
        end

        def toggle_expand(items)
          return if items.empty?

          item = items[@selected_idx]
          return unless item && item[:type] == :disk

          @expanded[item[:object].id] = !@expanded[item[:object].id]
        end

        def refresh_disks
          @status_bar.set_message("ディスク情報を更新中...")
          @services[:disk].refresh_all { |name| @status_bar.set_message("#{name} 更新中...") }
          @disks        = @services[:disk].list
          @vpses        = @services[:vps].list
          @selected_idx = 0
          @status_bar.set_message("ディスク情報を更新しました")
        rescue Api::BaseClient::ApiError => e
          @status_bar.set_error("API エラー: #{e.message}")
        rescue Faraday::Error => e
          @status_bar.set_error("接続エラー: #{e.message}")
        end
      end
    end
  end
end
