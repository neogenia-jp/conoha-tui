# frozen_string_literal: true

module ConohaTui
  module Ui
    module Screens
      # VPS 一覧画面。
      # 全アカウント・全リージョンの VPS をテーブルで表示する。
      class VpsListScreen < BaseScreen
        COLUMNS = [
          { header: "Ver",      width: 4,  field: :vps_version },
          { header: "ID",       width: 36, field: :id },
          { header: "名前",     width: 24, field: :name },
          { header: "CPU",      width: 5,  field: :vcpus },
          { header: "メモリ",   width: 8,  field: :ram_display },
          { header: "状態",     width: 10, field: :status },
          { header: "作成日",   width: 12, field: nil },
          { header: "契約期限", width: 12, field: nil },
          { header: "割引切符", width: 10, field: nil },
          { header: "リージョン", width: 6, field: :region }
        ].freeze

        SORT_LABELS = {
          name:             "名前",
          created_at:       "作成日",
          contract_end_at:  "契約期限"
        }.freeze

        def initialize(tui, services)
          super
          @vpses         = []
          @selected_idx  = 0
          @sort_by       = :name
          @sort_order    = :asc
          @filter        = nil
          @filter_mode   = false
          @filter_input  = ""
        end

        def on_activate
          @vpses        = load_vpses
          @selected_idx = 0
        end

        def render(frame, area = frame.area)
          help_area, content_area, status_area = build_layout(area)
          render_chrome(frame, help_area, status_area)

          if @filter_mode
            content_area, filter_area = @tui.layout_split(
              content_area,
              direction: :vertical,
              constraints: [
                @tui.constraint_fill(1),
                @tui.constraint_length(3)
              ]
            )
            frame.render_widget(render_filter_input, filter_area)
          end

          frame.render_widget(render_table, content_area)
        end

        def handle_input(event)
          if @filter_mode
            return handle_filter_input(event)
          end

          case event
          in { type: :key, code: "q" } | { type: :key, code: "c", modifiers: ["ctrl"] }
            :quit
          in type: :key, code: "down" | "j"
            move_selection(1)
          in type: :key, code: "up" | "k"
            move_selection(-1)
          in type: :key, code: "enter"
            :vps_detail
          in type: :key, code: "r"
            refresh_vpses
          in type: :key, code: "s"
            cycle_sort
          in type: :key, code: "S"
            toggle_sort_order
          in type: :key, code: "/"
            enter_filter_mode
          in type: :key, code: "escape"
            clear_filter
          else
            nil
          end
        end

        # 選択中の VPS を返す
        def selected_vps
          @vpses[@selected_idx]
        end

        private

        def setup_hints
          @help_bar.set_hints([
            ["↑/↓", "選択"],
            ["Enter", "詳細"],
            ["r", "更新"],
            ["s", "ソート切替"],
            ["S", "昇降順切替"],
            ["/", "フィルタ"],
            ["Esc", "フィルタ解除"],
            ["q", "終了"]
          ])
        end

        def load_vpses
          @services[:vps].list(sort_by: @sort_by, sort_order: @sort_order, filter: @filter)
        end

        def render_table
          rows = @vpses.each_with_index.map do |vps, i|
            status_style = vps.running? ? @tui.style(fg: :green) : @tui.style(fg: :red)

            @tui.table_row(
              cells: [
                "v#{vps.vps_version}",
                vps.id.to_s[0..7] + "…",
                vps.name.to_s,
                vps.vcpus.to_s,
                vps.ram_display,
                @tui.table_cell(content: status_label(vps), style: status_style),
                date_display(vps.created_at),
                date_display(vps.contract_end_at),
                vps.discount_ticket? ? "あり" : "-",
                vps.region.to_s
              ],
              style: i.even? ? @tui.style(bg: :reset) : nil
            )
          end

          widths = COLUMNS.map { |c| @tui.constraint_length(c[:width]) }

          sort_label = "#{SORT_LABELS[@sort_by]} #{@sort_order == :asc ? '↑' : '↓'}"
          filter_label = @filter ? " | フィルタ: #{@filter}" : ""
          title = "VPS 一覧 (#{@vpses.size}台) | ソート: #{sort_label}#{filter_label}"

          @tui.table(
            header:              COLUMNS.map { |c| c[:header] },
            rows:                rows,
            widths:              widths,
            selected_row:        @selected_idx,
            row_highlight_style: @tui.style(fg: :yellow, modifiers: [:bold]),
            highlight_symbol:    "▶ ",
            highlight_spacing:   :always,
            block:               @tui.block(title: title, borders: :all),
            footer:              []
          )
        end

        def render_filter_input
          @tui.paragraph(
            text: "フィルタ (名前/ホスト): #{@filter_input}█",
            block: @tui.block(title: "フィルタ入力 (Enter: 確定 / Esc: キャンセル)",
                              borders: :all)
          )
        end

        def handle_filter_input(event)
          case event
          in type: :key, code: "enter"
            @filter      = @filter_input.empty? ? nil : @filter_input
            @filter_mode = false
            @vpses       = load_vpses
            @selected_idx = 0
            @status_bar.set_message(@filter ? "フィルタ適用: #{@filter}" : "フィルタ解除")
          in type: :key, code: "escape"
            @filter_mode  = false
            @filter_input = @filter.to_s
          in type: :key, code: "backspace"
            @filter_input = @filter_input[0..-2].to_s
          in type: :key, code: code if code.length == 1
            @filter_input += code
          else
            nil
          end
          nil
        end

        def move_selection(delta)
          return if @vpses.empty?

          @selected_idx = [[@selected_idx + delta, 0].max, @vpses.size - 1].min
        end

        def cycle_sort
          fields = SORT_LABELS.keys
          idx    = fields.index(@sort_by) || 0
          @sort_by = fields[(idx + 1) % fields.size]
          @vpses   = load_vpses
          @status_bar.set_message("ソート: #{SORT_LABELS[@sort_by]}")
        end

        def toggle_sort_order
          @sort_order = @sort_order == :asc ? :desc : :asc
          @vpses      = load_vpses
          @status_bar.set_message("ソート順: #{@sort_order == :asc ? '昇順' : '降順'}")
        end

        def enter_filter_mode
          @filter_mode  = true
          @filter_input = @filter.to_s
        end

        def clear_filter
          @filter       = nil
          @filter_input = ""
          @vpses        = load_vpses
          @status_bar.set_message("フィルタ解除")
        end

        def refresh_vpses
          @status_bar.set_message("VPS 情報を更新中...")
          @services[:vps].refresh_all { |msg| @status_bar.set_message(msg) }
          @vpses        = load_vpses
          @selected_idx = 0
          @status_bar.set_message("VPS 情報を更新しました")
        rescue Api::BaseClient::ApiError => e
          @status_bar.set_error("API エラー: #{e.message}")
        rescue Faraday::Error => e
          @status_bar.set_error("接続エラー: #{e.message}")
        end

        def status_label(vps)
          case vps.status
          when "ACTIVE"   then "稼働中"
          when "SHUTOFF"  then "停止中"
          when "REBOOT"   then "再起動中"
          when "BUILDING" then "構築中"
          when "ERROR"    then "エラー"
          else vps.status.to_s
          end
        end

        def date_display(time)
          time ? time.strftime("%Y-%m-%d") : "-"
        end
      end
    end
  end
end
