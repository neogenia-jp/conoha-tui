# frozen_string_literal: true

module ConohaTui
  module Ui
    module Components
      # 画面上部に表示するヘルプバーコンポーネント。
      # 現在の画面で使えるキーバインドを表示する。
      class HelpBar
        def initialize(tui)
          @tui   = tui
          @hints = []
        end

        # ヒントを設定する
        # @param hints [Array<Array<String>>] [キー, 説明] のペア配列
        def set_hints(hints)
          @hints = hints
        end

        def widget
          hotkey_style = @tui.style(fg: :cyan, modifiers: [:bold])
          desc_style   = @tui.style(fg: :dark_gray)
          sep_style    = @tui.style(fg: :dark_gray)

          spans = []
          @hints.each_with_index do |(key, desc), i|
            spans << @tui.text_span(content: " #{key}", style: hotkey_style)
            spans << @tui.text_span(content: ":#{desc}", style: desc_style)
            spans << @tui.text_span(content: "  ", style: sep_style) unless i == @hints.size - 1
          end

          @tui.paragraph(
            text: @tui.text_line(spans: spans),
            block: @tui.block(borders: [:bottom])
          )
        end
      end
    end
  end
end
