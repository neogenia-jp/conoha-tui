# frozen_string_literal: true

module ConohaTui
  module Ui
    module Screens
      # VPS 詳細画面。
      # 選択した VPS の詳細情報・電源操作・ポート管理を行う。
      class VpsDetailScreen < BaseScreen
        PORT_PROTOCOLS = %w[tcp udp icmp].freeze

        def initialize(tui, services)
          super
          @vps           = nil
          @ports         = []
          @selected_port = 0
          @focus         = :info  # :info, :ports
          @power_confirm = false
          # ポート追加ダイアログ用
          @port_dialog        = false
          @port_dialog_field  = :protocol  # :protocol, :port, :ip
          @port_dialog_proto  = 0
          @port_dialog_port   = ""
          @port_dialog_ip     = "0.0.0.0/0"
        end

        def set_vps(vps)
          @vps           = vps
          @ports         = load_ports
          @selected_port = 0
        end

        def on_activate
          @ports = load_ports if @vps
        end

        def render(frame, area = frame.area)
          help_area, content_area, status_area = build_layout(area)
          render_chrome(frame, help_area, status_area)

          # 左右 2 分割: 詳細情報 | ポート一覧
          info_area, port_area = @tui.layout_split(
            content_area,
            direction: :horizontal,
            constraints: [
              @tui.constraint_percentage(50),
              @tui.constraint_fill(1)
            ]
          )

          frame.render_widget(render_info, info_area)
          frame.render_widget(render_ports, port_area)

          if @power_confirm
            frame.render_widget(render_power_confirm_dialog, centered_rect(area, 60, 8))
          end

          # ポート追加ダイアログ
          if @port_dialog
            frame.render_widget(render_port_dialog, centered_rect(area, 70, 9))
          end
        end

        def handle_input(event)
          return handle_power_confirm_input(event) if @power_confirm
          return handle_port_dialog_input(event) if @port_dialog

          case event
          in { type: :key, code: "q" } | { type: :key, code: "c", modifiers: ["ctrl"] }
            :quit
          in type: :key, code: "escape" | "esc" | "backspace"
            :back
          in type: :key, code: "tab"
            toggle_focus
          in type: :key, code: "s"
            toggle_power
          in type: :key, code: "r"
            refresh_vps
          in type: :key, code: "down" | "j" if @focus == :ports
            move_port_selection(1)
          in type: :key, code: "up" | "k" if @focus == :ports
            move_port_selection(-1)
          in type: :key, code: "o" if @focus == :ports
            open_port_dialog
          in type: :key, code: "d" | "delete" if @focus == :ports
            close_port
          else
            nil
          end
        end

        private

        def setup_hints
          @help_bar.set_hints([
            ["Tab", "フォーカス切替"],
            ["s", "電源ON/OFF"],
            ["r", "再取得"],
            ["o", "ポート開放"],
            ["d", "ポートクローズ"],
            ["Esc", "一覧に戻る"]
          ])
        end

        def load_ports
          return [] unless @vps

          @services[:network].list_ports(server_id: @vps.id)
        end

        def render_info
          return @tui.paragraph(text: "VPS が選択されていません") unless @vps

          border_style = @focus == :info ? @tui.style(fg: :cyan) : @tui.style(fg: :dark_gray)

          lines = [
            @tui.text_line(spans: [
              @tui.text_span(content: "ネームタグ:     ", style: @tui.style(fg: :dark_gray)),
              @tui.text_span(content: @vps.metadata['instance_name_tag'], style: @tui.style(modifiers: [:bold]))
            ]),
            @tui.text_line(spans: [
              @tui.text_span(content: "名前:     ", style: @tui.style(fg: :dark_gray)),
              @tui.text_span(content: @vps.name.to_s, style: @tui.style(modifiers: [:bold]))
            ]),
            @tui.text_line(spans: [
              @tui.text_span(content: "ID:       ", style: @tui.style(fg: :dark_gray)),
              @tui.text_span(content: @vps.id.to_s)
            ]),
            @tui.text_line(spans: [
              @tui.text_span(content: "状態:     ", style: @tui.style(fg: :dark_gray)),
              @tui.text_span(content: power_status_label, style: power_status_style)
            ]),
            @tui.text_line(spans: [
              @tui.text_span(content: "バージョン: ", style: @tui.style(fg: :dark_gray)),
              @tui.text_span(content: "v#{@vps.vps_version}")
            ]),
            @tui.text_line(spans: [
              @tui.text_span(content: "リージョン: ", style: @tui.style(fg: :dark_gray)),
              @tui.text_span(content: @vps.region.to_s)
            ]),
            @tui.text_line(spans: [
              @tui.text_span(content: "CPU:      ", style: @tui.style(fg: :dark_gray)),
              @tui.text_span(content: cpu_display)
            ]),
            @tui.text_line(spans: [
              @tui.text_span(content: "メモリ:   ", style: @tui.style(fg: :dark_gray)),
              @tui.text_span(content: @vps.ram_display)
            ]),
            @tui.text_line(spans: [
              @tui.text_span(content: "グローバルIP: ", style: @tui.style(fg: :dark_gray)),
              @tui.text_span(content: @vps.global_ips.join(", ").then { |s| s.empty? ? "-" : s })
            ]),
            @tui.text_line(spans: [
              @tui.text_span(content: "内部IP:   ", style: @tui.style(fg: :dark_gray)),
              @tui.text_span(content: @vps.private_ips.join(", ").then { |s| s.empty? ? "-" : s })
            ]),
            @tui.text_line(spans: [
              @tui.text_span(content: "収容ホスト: ", style: @tui.style(fg: :dark_gray)),
              @tui.text_span(content: @vps.host_id.to_s.then { |s| s.empty? ? "-" : s })
            ]),
            @tui.text_line(spans: [
              @tui.text_span(content: "作成日:   ", style: @tui.style(fg: :dark_gray)),
              @tui.text_span(content: date_display(@vps.created_at))
            ]),
            @tui.text_line(spans: [
              @tui.text_span(content: "契約期限: ", style: @tui.style(fg: :dark_gray)),
              @tui.text_span(content: date_display(@vps.contract_end_at))
            ]),
            @tui.text_line(spans: [
              @tui.text_span(content: "割引切符: ", style: @tui.style(fg: :dark_gray)),
              @tui.text_span(content: @vps.discount_ticket? ? @vps.discount_ticket : "-")
            ])
          ]

          @tui.paragraph(
            text: lines,
            block: @tui.block(
              title: "VPS 詳細",
              borders: :all,
              style: border_style
            )
          )
        end

        def render_ports
          border_style = @focus == :ports ? @tui.style(fg: :cyan) : @tui.style(fg: :dark_gray)

          ingress_ports = @ports.select { |p| p.direction == "ingress" }

          rows = ingress_ports.each_with_index.map do |port, _i|
            @tui.table_row(
              cells: [
                port.port_display,
                port.remote_ip_prefix.to_s,
                port.sg_name.to_s
              ]
            )
          end

          widths = [
            @tui.constraint_length(16),
            @tui.constraint_length(20),
            @tui.constraint_fill(1)
          ]

          @tui.table(
            header:              ["プロトコル/ポート", "許可IP", "セキュリティG"],
            rows:                rows,
            widths:              widths,
            selected_row:        @focus == :ports ? @selected_port : nil,
            row_highlight_style: @tui.style(fg: :yellow, modifiers: [:bold]),
            highlight_symbol:    "▶ ",
            highlight_spacing:   :when_selected,
            block:               @tui.block(
              title: "ポート開放状況 (#{ingress_ports.size}件)",
              borders: :all,
              style: border_style
            )
          )
        end

        def render_port_dialog
          proto = PORT_PROTOCOLS[@port_dialog_proto]
          field_styles = {
            protocol: @tui.style(fg: :yellow, modifiers: [:bold]),
            port:     @tui.style(fg: :yellow, modifiers: [:bold]),
            ip:       @tui.style(fg: :yellow, modifiers: [:bold])
          }
          base_style = @tui.style(fg: :white)

          lines = [
            @tui.text_line(spans: [
              @tui.text_span(content: "プロトコル: ",
                             style: @port_dialog_field == :protocol ? field_styles[:protocol] : base_style),
              @tui.text_span(content: "#{proto} (←/→で変更)", style: @tui.style(fg: :cyan))
            ]),
            @tui.text_line(spans: [
              @tui.text_span(content: "ポート番号: ",
                             style: @port_dialog_field == :port ? field_styles[:port] : base_style),
              @tui.text_span(content: @port_dialog_port + (@port_dialog_field == :port ? "█" : ""),
                             style: @tui.style(fg: :cyan))
            ]),
            @tui.text_line(spans: [
              @tui.text_span(content: "許可 IP:    ",
                             style: @port_dialog_field == :ip ? field_styles[:ip] : base_style),
              @tui.text_span(content: @port_dialog_ip + (@port_dialog_field == :ip ? "█" : ""),
                             style: @tui.style(fg: :cyan))
            ]),
            @tui.text_line(spans: [
              @tui.text_span(content: " Tab: 項目移動 | Enter: 開放 | Esc: キャンセル",
                             style: @tui.style(fg: :dark_gray))
            ])
          ]

          @tui.paragraph(
            text: lines,
            block: @tui.block(title: "ポート開放", borders: :all,
                              style: @tui.style(fg: :green))
          )
        end

        def render_power_confirm_dialog
          action = @vps&.running? ? "停止" : "起動"
          lines = [
            @tui.text_line(spans: [
              @tui.text_span(content: "この VPS を#{action}しますか？", style: @tui.style(fg: :yellow, modifiers: [:bold]))
            ]),
            @tui.text_line(spans: [
              @tui.text_span(content: "", style: @tui.style(fg: :white))
            ]),
            @tui.text_line(spans: [
              @tui.text_span(content: "Enter / y: 実行    Esc / n: キャンセル", style: @tui.style(fg: :dark_gray))
            ])
          ]

          @tui.paragraph(
            text: lines,
            block: @tui.block(title: "電源操作の確認", borders: :all,
                              style: @tui.style(fg: :yellow))
          )
        end

        def handle_power_confirm_input(event)
          case event
          in type: :key, code: "enter" | "y"
            @power_confirm = false
            execute_toggle_power
          in type: :key, code: "escape" | "esc" | "n"
            @power_confirm = false
            @status_bar.set_message("電源操作をキャンセルしました")
          else
            nil
          end
          nil
        end

        def handle_port_dialog_input(event)
          case event
          in type: :key, code: "escape" | "esc"
            @port_dialog = false
          in type: :key, code: "tab"
            fields = %i[protocol port ip]
            idx    = fields.index(@port_dialog_field) || 0
            @port_dialog_field = fields[(idx + 1) % fields.size]
          in type: :key, code: "enter"
            execute_open_port
          in type: :key, code: "left" if @port_dialog_field == :protocol
            @port_dialog_proto = (@port_dialog_proto - 1) % PORT_PROTOCOLS.size
          in type: :key, code: "right" if @port_dialog_field == :protocol
            @port_dialog_proto = (@port_dialog_proto + 1) % PORT_PROTOCOLS.size
          in type: :key, code: "backspace" if @port_dialog_field == :port
            @port_dialog_port = @port_dialog_port[0..-2].to_s
          in type: :key, code: "backspace" if @port_dialog_field == :ip
            @port_dialog_ip = @port_dialog_ip[0..-2].to_s
          in type: :key, code: code if code.length == 1 && @port_dialog_field == :port
            @port_dialog_port += code if code =~ /\d/
          in type: :key, code: code if code.length == 1 && @port_dialog_field == :ip
            @port_dialog_ip += code
          else
            nil
          end
          nil
        end

        def toggle_focus
          @focus = @focus == :info ? :ports : :info
        end

        def toggle_power
          @power_confirm = true
        end

        def execute_toggle_power
          return unless @vps

          begin
            if @vps.running?
              @status_bar.set_message("電源をOFFにしています...")
              @services[:vps].stop(@vps)
              @status_bar.set_message("電源をOFFにしました")
            else
              @status_bar.set_message("電源をONにしています...")
              @services[:vps].start(@vps)
              @status_bar.set_message("電源をONにしました")
            end
          rescue => e
            @status_bar.set_error("電源操作に失敗: #{e.message}")
          end
        end

        def refresh_vps
          return unless @vps

          begin
            @status_bar.set_message("VPS 情報を再取得中...")
            @vps  = @services[:vps].refresh_vps(@vps)
            @ports = load_ports
            @status_bar.set_message("VPS 情報を更新しました")
          rescue => e
            @status_bar.set_error("再取得に失敗: #{e.message}")
          end
        end

        def open_port_dialog
          @port_dialog       = true
          @port_dialog_field = :protocol
          @port_dialog_proto = 0
          @port_dialog_port  = ""
          @port_dialog_ip    = "0.0.0.0/0"
        end

        def execute_open_port
          return unless @vps

          port_num = @port_dialog_port.to_i
          if port_num < 1 || port_num > 65535
            @status_bar.set_error("無効なポート番号: #{@port_dialog_port}")
            @port_dialog = false
            return
          end

          begin
            @status_bar.set_message("ポートを開放中...")
            @services[:network].open_port(
              vps:              @vps,
              protocol:         PORT_PROTOCOLS[@port_dialog_proto],
              port:             port_num,
              remote_ip_prefix: @port_dialog_ip
            )
            @ports = load_ports
            @status_bar.set_message("ポート #{@port_dialog_port} を開放しました")
          rescue => e
            @status_bar.set_error("ポート開放に失敗: #{e.message}")
          ensure
            @port_dialog = false
          end
        end

        def close_port
          return unless @vps

          ingress_ports = @ports.select { |p| p.direction == "ingress" }
          port = ingress_ports[@selected_port]
          return unless port

          begin
            @status_bar.set_message("ポートをクローズ中...")
            @services[:network].close_port(port, vps: @vps)
            @ports         = load_ports
            @selected_port = [@selected_port, @ports.size - 1].min
            @status_bar.set_message("ポート #{port.port_display} をクローズしました")
          rescue => e
            @status_bar.set_error("ポートクローズに失敗: #{e.message}")
          end
        end

        def move_port_selection(delta)
          ingress_count = @ports.count { |p| p.direction == "ingress" }
          return if ingress_count.zero?

          @selected_port = [[@selected_port + delta, 0].max, ingress_count - 1].min
        end

        def power_status_label
          @vps.running? ? "稼働中 ●" : "停止中 ○"
        end

        def power_status_style
          @vps.running? ? @tui.style(fg: :green, modifiers: [:bold]) : @tui.style(fg: :red)
        end

        def date_display(time)
          time ? time.strftime("%Y-%m-%d") : "-"
        end

        def cpu_display
          @vps.vcpus ? "#{@vps.vcpus} コア" : "-"
        end

        def centered_rect(area, width_percent, height)
          top, middle, _bottom = @tui.layout_split(
            area,
            direction: :vertical,
            constraints: [
              @tui.constraint_fill(1),
              @tui.constraint_length(height),
              @tui.constraint_fill(1)
            ]
          )

          _left, center, _right = @tui.layout_split(
            middle,
            direction: :horizontal,
            constraints: [
              @tui.constraint_fill(1),
              @tui.constraint_percentage(width_percent),
              @tui.constraint_fill(1)
            ]
          )
          center
        end
      end
    end
  end
end
