# frozen_string_literal: true

module ConohaTui
  module Ui
    module Components
      # 画面下部に表示するステータスバーコンポーネント。
      # メッセージ、最終更新日時、エラー状態を表示する。
      class StatusBar
        def initialize(tui)
          @tui     = tui
          @message = "準備完了"
          @error   = nil
          @updated_at = nil
        end

        def set_message(msg)
          @message    = msg
          @error      = nil
          @updated_at = Time.now
        end

        def set_error(msg)
          @error   = msg
          @updated_at = Time.now
        end

        def clear_error
          @error = nil
        end

        # RatatuiRuby のウィジェットを返す
        def widget
          text = build_text
          @tui.paragraph(
            text: text,
            block: @tui.block(borders: [:top])
          )
        end

        private

        def build_text
          if @error
            @tui.text_line(spans: [
              @tui.text_span(content: " エラー: ", style: @tui.style(fg: :red, modifiers: [:bold])),
              @tui.text_span(content: @error,      style: @tui.style(fg: :red))
            ])
          else
            updated_str = @updated_at ? " | 更新: #{@updated_at.strftime('%H:%M:%S')}" : ""
            @tui.text_line(spans: [
              @tui.text_span(content: " #{@message}#{updated_str}",
                             style: @tui.style(fg: :dark_gray))
            ])
          end
        end
      end
    end
  end
end
