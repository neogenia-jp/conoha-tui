# frozen_string_literal: true

module ConohaTui
  module Ui
    module Screens
      # オブジェクトストレージ一覧画面。
      # コンテナと接続（所属）VPS をツリー形式で表示する。
      class ObjectStorageScreen < BaseScreen
        def initialize(tui, services)
          super
          @containers   = []
          @selected_idx = 0
        end

        def on_activate
          @containers   = @services[:object_storage].list
          @selected_idx = 0
        end

        def render(frame, area = frame.area)
          help_area, content_area, status_area = build_layout(area)
          render_chrome(frame, help_area, status_area)
          frame.render_widget(render_list, content_area)
        end

        def handle_input(event)
          case event
          in { type: :key, code: "q" } | { type: :key, code: "c", modifiers: ["ctrl"] }
            :quit
          in type: :key, code: "down" | "j"
            @selected_idx = [[@selected_idx + 1, 0].max, [@containers.size - 1, 0].max].min
          in type: :key, code: "up" | "k"
            @selected_idx = [@selected_idx - 1, 0].max
          in type: :key, code: "r"
            refresh_containers
          else
            nil
          end
        end

        private

        def setup_hints
          @help_bar.set_hints([
            ["↑/↓", "移動"],
            ["r", "更新"],
            ["q", "終了"]
          ])
        end

        def render_list
          rows = @containers.each_with_index.map do |container, i|
            @tui.table_row(
              cells: [
                container.name.to_s,
                container.count.to_s,
                container.bytes_display,
                container.account_name.to_s,
                container.region.to_s
              ],
              style: i.even? ? @tui.style(bg: :reset) : nil
            )
          end

          widths = [
            @tui.constraint_fill(1),
            @tui.constraint_length(10),
            @tui.constraint_length(12),
            @tui.constraint_length(16),
            @tui.constraint_length(6)
          ]

          @tui.table(
            header:              ["コンテナ名", "オブジェクト数", "使用容量", "アカウント", "リージョン"],
            rows:                rows,
            widths:              widths,
            selected_row:        @selected_idx,
            row_highlight_style: @tui.style(fg: :yellow, modifiers: [:bold]),
            highlight_symbol:    "▶ ",
            highlight_spacing:   :when_selected,
            block:               @tui.block(
              title: "オブジェクトストレージ (#{@containers.size}件)",
              borders: :all
            )
          )
        end

        def refresh_containers
          @status_bar.set_message("オブジェクトストレージ情報を更新中...")
          errors = @services[:object_storage].refresh_all do |name|
            @status_bar.set_message("#{name} 更新中...")
          end
          @containers   = @services[:object_storage].list
          @selected_idx = 0
          report_refresh_result(errors, "オブジェクトストレージ情報を更新しました")
        rescue Api::BaseClient::ApiError => e
          @status_bar.set_error("API エラー: #{e.message}")
        rescue Faraday::Error => e
          @status_bar.set_error("接続エラー: #{e.message}")
        end
      end
    end
  end
end
