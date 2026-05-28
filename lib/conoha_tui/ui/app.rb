# frozen_string_literal: true

module ConohaTui
  module Ui
    # メインアプリケーションクラス。
    # RatatuiRuby のイベントループを管理し、画面遷移を制御する。
    class App
      TABS = [
        { label: "VPS一覧",          key: :vps_list },
        { label: "内部ネットワーク", key: :network_list },
        { label: "追加ディスク",     key: :disk_list },
        { label: "オブジェクトST",   key: :object_storage },
        { label: "設定",             key: :settings }
      ].freeze

      def initialize
        @settings = Config::Settings.new
        @services = build_services
        @current_tab   = 0
        @screen_stack  = []
        @screens       = {}
      end

      def run
        RatatuiRuby.run do |tui|
          @tui = tui
          init_screens

          # 初回起動時は設定画面を表示
          if @settings.empty?
            push_screen(:settings)
          else
            push_screen(TABS[@current_tab][:key])
          end

          loop do
            @tui.draw { |frame| render(frame) }
            break if handle_input == :quit
          end
        end
      end

      private

      def build_services
        {
          settings:        @settings,
          vps:             Services::VpsService.new(@settings),
          network:         Services::NetworkService.new(@settings),
          disk:            Services::DiskService.new(@settings),
          object_storage:  Services::ObjectStorageService.new(@settings)
        }
      end

      def init_screens
        @screens = {
          vps_list:       Screens::VpsListScreen.new(@tui, @services),
          vps_detail:     Screens::VpsDetailScreen.new(@tui, @services),
          network_list:   Screens::NetworkListScreen.new(@tui, @services),
          disk_list:      Screens::DiskListScreen.new(@tui, @services),
          object_storage: Screens::ObjectStorageScreen.new(@tui, @services),
          settings:       Screens::SettingsScreen.new(@tui, @services)
        }
      end

      def current_screen
        @screen_stack.last
      end

      def push_screen(key)
        screen = @screens[key]
        return unless screen

        screen.on_activate
        @screen_stack.push(screen)
      end

      def pop_screen
        @screen_stack.pop if @screen_stack.size > 1
      end

      def render(frame)
        # タブバー + コンテンツ の 2 分割
        tab_area, content_area = @tui.layout_split(
          frame.area,
          direction: :vertical,
          constraints: [
            @tui.constraint_length(3),
            @tui.constraint_fill(1)
          ]
        )

        render_tabs(frame, tab_area)
        current_screen&.render(frame, content_area)
      end

      def render_tabs(frame, area)
        tab_labels = TABS.map { |t| t[:label] }
        tabs = @tui.tabs(
          titles:          tab_labels,
          selected_index:  @current_tab,
          block:           @tui.block(borders: [:all]),
          divider:         " │ ",
          highlight_style: @tui.style(fg: :cyan, modifiers: [:bold])
        )
        frame.render_widget(tabs, area)
      end

      def handle_input
        event = @tui.poll_event

        # グローバルキー
        case event
        in { type: :key, code: "q", modifiers: [] } |
           { type: :key, code: "c", modifiers: ["ctrl"] }
          return :quit
        in type: :key, code: code, modifiers: modifiers if %w[1 2 3 4 5].include?(code) && modifiers.include?("alt")
          idx = code.to_i - 1
          switch_tab(idx)
          return nil
        in type: :key, code: "right", modifiers: ["alt"]
          switch_tab((@current_tab + 1) % TABS.size)
          return nil
        in type: :key, code: "left", modifiers: ["alt"]
          switch_tab((@current_tab - 1) % TABS.size)
          return nil
        else
          # 画面固有の処理に委譲
        end

        result = current_screen&.handle_input(event)

        case result
        when :quit
          :quit
        when :back
          pop_screen
          nil
        when :vps_detail
          if (vps_list = @screens[:vps_list]) && (detail = @screens[:vps_detail])
            detail.set_vps(vps_list.selected_vps)
            push_screen(:vps_detail)
          end
          nil
        else
          nil
        end
      end

      def switch_tab(idx)
        return if idx < 0 || idx >= TABS.size

        @current_tab  = idx
        @screen_stack = []
        push_screen(TABS[@current_tab][:key])
      end
    end
  end
end
