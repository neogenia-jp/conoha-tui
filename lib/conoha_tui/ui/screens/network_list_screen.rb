# frozen_string_literal: true

module ConohaTui
  module Ui
    module Screens
      # 内部ネットワーク一覧画面。
      # ネットワークと接続 VPS をツリー形式で表示する。
      class NetworkListScreen < BaseScreen
        def initialize(tui, services)
          super
          @networks      = []
          @vpses         = []
          @selected_idx  = 0
          @expanded      = {}
        end

        def on_activate
          @networks = @services[:network].list_networks
          @vpses    = @services[:vps].list
          @selected_idx = 0
          @expanded = {}
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
            @selected_idx = [[@selected_idx + 1, 0].max, items.size - 1].min
          in type: :key, code: "up" | "k"
            @selected_idx = [@selected_idx - 1, 0].max
          in type: :key, code: "enter" | "space"
            toggle_expand(items)
          in type: :key, code: "r"
            refresh_networks
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

        # ツリーの表示アイテムを構築する
        # 各アイテムは { type:, object:, depth:, key: } の形式
        def build_tree_items
          items = []
          @networks.each do |network|
            items << { type: :network, object: network, depth: 0, key: network.id }
            next unless @expanded[network.id]

            network.connected_server_ids.each do |server_id|
              vps = @vpses.find { |v| v.id == server_id }
              label = vps ? "#{vps.name} (#{vps.status})" : "ID: #{server_id[0..7]}…"
              items << { type: :vps, label: label, depth: 1, key: "#{network.id}-#{server_id}" }
            end
          end
          items
        end

        def render_tree
          items = build_tree_items
          list_items = items.each_with_index.map do |item, _i|
            case item[:type]
            when :network
              expanded = @expanded[item[:object].id]
              icon     = item[:object].connected_server_ids.empty? ? "  " : (expanded ? "▼ " : "▶ ")
              @tui.list_item(
                content: @tui.text_line(spans: [
                  @tui.text_span(content: icon, style: @tui.style(fg: :yellow)),
                  @tui.text_span(content: item[:object].name.to_s,
                                 style: @tui.style(modifiers: [:bold])),
                  @tui.text_span(content: " (VPS #{item[:object].connected_server_ids.size}台)",
                                 style: @tui.style(fg: :dark_gray))
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
            items:            list_items,
            selected_index:   @selected_idx,
            highlight_style:  @tui.style(fg: :yellow, modifiers: [:bold]),
            highlight_symbol: "",
            highlight_spacing: :when_selected,
            block:            @tui.block(
              title: "内部ネットワーク一覧 (#{@networks.size}件)",
              borders: :all
            )
          )
        end

        def toggle_expand(items)
          return if items.empty?

          item = items[@selected_idx]
          return unless item && item[:type] == :network

          network_id = item[:object].id
          @expanded[network_id] = !@expanded[network_id]
        end

        def refresh_networks
          @status_bar.set_message("ネットワーク情報を更新中...")
          errors        = @services[:network].refresh_all { |name| @status_bar.set_message("#{name} 更新中...") }
          @networks     = @services[:network].list_networks
          @vpses        = @services[:vps].list
          @selected_idx = 0
          report_refresh_result(errors, "ネットワーク情報を更新しました")
        rescue Api::BaseClient::ApiError => e
          @status_bar.set_error("API エラー: #{e.message}")
        rescue Faraday::Error => e
          @status_bar.set_error("接続エラー: #{e.message}")
        end
      end
    end
  end
end
