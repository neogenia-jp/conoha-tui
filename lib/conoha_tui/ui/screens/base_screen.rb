# frozen_string_literal: true

module ConohaTui
  module Ui
    module Screens
      # すべての画面の基底クラス。
      # 共通のレイアウト（ヘルプバー・ステータスバー）と
      # ライフサイクルメソッドを提供する。
      class BaseScreen
        HELP_BAR_HEIGHT   = 2
        STATUS_BAR_HEIGHT = 2

        attr_reader :tui, :status_bar, :help_bar

        def initialize(tui, services)
          @tui        = tui
          @services   = services
          @status_bar = Components::StatusBar.new(tui)
          @help_bar   = Components::HelpBar.new(tui)
          setup_hints
        end

        # 画面を描画する（サブクラスで実装する）
        # @param frame [RatatuiRuby::Frame]
        # @param area  [RatatuiRuby::Layout::Rect] 描画対象エリア（省略時は frame.area 全体）
        def render(frame, area = frame.area)
          raise NotImplementedError, "#{self.class}#render を実装してください"
        end

        # キー入力を処理する。
        # @return [Symbol, nil] :quit でアプリ終了、:back で前の画面に戻る、
        #                       その他の Symbol で画面遷移のシグナル
        def handle_input(event)
          nil
        end

        # 画面がアクティブになったときに呼ばれる（必要に応じてオーバーライド）
        def on_activate
        end

        protected

        # 3 分割レイアウトを返す [help_area, content_area, status_area]
        def build_layout(frame_area)
          @tui.layout_split(
            frame_area,
            direction: :vertical,
            constraints: [
              @tui.constraint_length(HELP_BAR_HEIGHT),
              @tui.constraint_fill(1),
              @tui.constraint_length(STATUS_BAR_HEIGHT)
            ]
          )
        end

        # ヘルプバーとステータスバーを描画する
        def render_chrome(frame, help_area, status_area)
          frame.render_widget(@help_bar.widget, help_area)
          frame.render_widget(@status_bar.widget, status_area)
        end

        # 全アカウント再取得の結果をステータスバーに表示する。
        # 一部のアカウントが失敗していてもエラーとして残りの結果と合わせて通知する。
        def report_refresh_result(errors, success_message)
          if errors.empty?
            @status_bar.set_message(success_message)
          else
            failed = errors.map { |name, message| "#{name}: #{message}" }.join(" / ")
            @status_bar.set_error("一部のアカウントで取得に失敗しました（#{failed}）")
          end
        end

        # サブクラスでキーヒントをセットする
        def setup_hints
        end
      end
    end
  end
end
