# frozen_string_literal: true

module ConohaTui
  module Ui
    module Screens
      # 設定画面。
      # ConoHa API アカウント情報の登録・編集・削除を行う。
      # 初回起動時は自動的にこの画面が表示される。
      class SettingsScreen < BaseScreen
        # ConoHa VPS のバージョンごとにリージョン名が異なる
        REGIONS_BY_VERSION = {
          2 => %w[tyo1 tyo2 tyo3 sin1 sjc1].freeze,
          3 => %w[c3j1].freeze
        }.freeze
        VERSIONS = [2, 3].freeze

        FIELD_LABELS = {
          name:      "表示名",
          tenant_id: "テナントID",
          username:  "ユーザー名",
          user_id:   "ユーザーID",
          password:  "パスワード",
          region:    "リージョン",
          version:   "VPS バージョン"
        }.freeze

        def initialize(tui, services)
          super
          @settings      = services[:settings]
          @accounts      = []
          @selected_idx  = 0
          @mode          = :list   # :list, :add, :edit
          @form          = {}
          @form_field    = 0
          @field_cursor  = {}
        end

        def on_activate
          @accounts = @settings.accounts
        end

        def render(frame, area = frame.area)
          help_area, content_area, status_area = build_layout(area)
          render_chrome(frame, help_area, status_area)

          case @mode
          when :list
            frame.render_widget(render_account_list, content_area)
          when :add, :edit
            frame.render_widget(render_form, content_area)
          end
        end

        def handle_input(event)
          case @mode
          when :list  then handle_list_input(event)
          when :add, :edit then handle_form_input(event)
          end
        end

        private

        def setup_hints
          @help_bar.set_hints([
            ["a", "追加"],
            ["e", "編集"],
            ["d", "削除"],
            ["q", "終了"]
          ])
        end

        # ---- リスト画面 ----

        def render_account_list
          rows = @accounts.each_with_index.map do |account, _i|
            @tui.table_row(
              cells: [
                account.name.to_s,
                account.tenant_id.to_s,
                account.v2? ? account.username.to_s : account.user_id.to_s,
                account.region.to_s,
                "v#{account.version}"
              ]
            )
          end

          widths = [
            @tui.constraint_length(16),
            @tui.constraint_length(20),
            @tui.constraint_fill(1),
            @tui.constraint_length(6),
            @tui.constraint_length(4)
          ]

          hint = @accounts.empty? ? " [a] キーを押してアカウントを追加してください" : ""
          @tui.table(
            header:              ["表示名", "テナントID", "ユーザー名/ID", "リージョン", "Ver"],
            rows:                rows,
            widths:              widths,
            selected_row:        @accounts.empty? ? nil : @selected_idx,
            row_highlight_style: @tui.style(fg: :yellow, modifiers: [:bold]),
            highlight_symbol:    "▶ ",
            highlight_spacing:   :when_selected,
            block:               @tui.block(
              title: "アカウント設定#{hint}",
              borders: :all
            )
          )
        end

        def handle_list_input(event)
          case event
          in { type: :key, code: "q" } | { type: :key, code: "c", modifiers: ["ctrl"] }
            :quit
          in type: :key, code: "down" | "j"
            @selected_idx = [[@selected_idx + 1, 0].max, [@accounts.size - 1, 0].max].min
          in type: :key, code: "up" | "k"
            @selected_idx = [@selected_idx - 1, 0].max
          in type: :key, code: "a"
            enter_add_mode
          in type: :key, code: "e"
            enter_edit_mode
          in type: :key, code: "d"
            delete_account
          else
            nil
          end
        end

        # ---- フォーム画面 ----

        def render_form
          is_add = @mode == :add
          title  = is_add ? "アカウント追加" : "アカウント編集"
          fields = form_fields

          lines = fields.each_with_index.map do |field, i|
            label  = field_label(field)
            active = i == @form_field
            label_style  = active ? @tui.style(fg: :cyan, modifiers: [:bold]) : @tui.style(fg: :white)
            value_style  = active ? @tui.style(fg: :yellow) : @tui.style(fg: :white)

            value_str = field_display_value(field)
            cursor    = active ? "█" : ""

            @tui.text_line(spans: [
              @tui.text_span(content: format("%-14s", "#{label}: "), style: label_style),
              @tui.text_span(content: "#{value_str}#{cursor}",       style: value_style)
            ])
          end

          lines << @tui.text_line(spans: [
            @tui.text_span(content: "",
                           style: @tui.style(fg: :dark_gray))
          ])
          lines << @tui.text_line(spans: [
            @tui.text_span(content: " Tab: 項目移動  Enter: 保存  Esc: キャンセル  Cmd+V: ペースト",
                           style: @tui.style(fg: :dark_gray))
          ])

          @tui.paragraph(
            text: lines,
            block: @tui.block(title: title, borders: :all,
                              style: @tui.style(fg: :green))
          )
        end

        def field_display_value(field)
          value = @form[field].to_s
          case field
          when :password
            "*" * value.length
          when :region
            "#{value} (←/→で変更)"
          when :version
            "#{value} (←/→で変更)"
          else
            value
          end
        end

        def handle_form_input(event)
          fields = form_fields
          @form_field = [@form_field, fields.size - 1].min
          field = fields[@form_field]

          case event
          in type: :key, code: "escape"
            @mode = :list
          in type: :key, code: "tab"
            @form_field = (@form_field + 1) % fields.size
          in type: :key, code: "enter"
            save_form
          in type: :key, code: "left" if field == :region
            regions = regions_for(@form[:version])
            idx = regions.index(@form[:region].to_s) || 0
            @form[:region] = regions[(idx - 1) % regions.size]
          in type: :key, code: "right" if field == :region
            regions = regions_for(@form[:version])
            idx = regions.index(@form[:region].to_s) || 0
            @form[:region] = regions[(idx + 1) % regions.size]
          in type: :key, code: "left" | "right" if field == :version
            idx = VERSIONS.index(@form[:version]) || 0
            @form[:version] = VERSIONS[(idx + 1) % VERSIONS.size]
            @form[:region]  = regions_for(@form[:version]).first
            @form_field = [@form_field, form_fields.size - 1].min
          in type: :key, code: "backspace"
            current = @form[field].to_s
            @form[field] = current[0..-2]
          in { type: :paste } if !%i[region version].include?(field)
            @form[field] = @form[field].to_s + event.content.gsub(/\r?\n/, "")
          in type: :key, code: code if code.length == 1 && !%i[region version].include?(field)
            @form[field] = @form[field].to_s + code
          else
            nil
          end
          nil
        end

        def enter_add_mode
          @mode       = :add
          @form_field = 0
          @form       = {
            name: "", tenant_id: "", username: "", user_id: "",
            password: "", region: regions_for(2).first, version: 2
          }
        end

        def enter_edit_mode
          return if @accounts.empty?

          account    = @accounts[@selected_idx]
          @mode      = :edit
          @form_field = 0
          @form = {
            name:        account.name,
            tenant_id:   account.tenant_id.to_s,
            username:    account.username,
            user_id:     account.user_id.to_s,
            password:    account.password,
            region:      account.region,
            version:     account.version
          }
        end

        def save_form
          empty = form_fields.select { |f| @form[f].to_s.strip.empty? }
          if empty.any?
            @status_bar.set_error("必須項目が空です: #{empty.map { |f| field_label(f) }.join(', ')}")
            return
          end

          attrs = normalized_form_attrs

          if @mode == :add
            @settings.add_account(
              name:        attrs[:name],
              tenant_id:   attrs[:tenant_id],
              username:    attrs[:username],
              user_id:     attrs[:user_id],
              password:    attrs[:password],
              region:      attrs[:region],
              version:     attrs[:version]
            )
            @status_bar.set_message("アカウント '#{@form[:name]}' を追加しました")
          else
            @settings.update_account(@selected_idx, attrs.transform_keys(&:to_s))
            @status_bar.set_message("アカウント '#{@form[:name]}' を更新しました")
          end

          @accounts = @settings.accounts
          @mode     = :list
        end

        def delete_account
          return if @accounts.empty?

          name = @accounts[@selected_idx].name
          @settings.delete_account(@selected_idx)
          @accounts     = @settings.accounts
          @selected_idx = [@selected_idx, @accounts.size - 1].min
          @selected_idx = 0 if @selected_idx < 0
          @status_bar.set_message("アカウント '#{name}' を削除しました")
        end

        def form_fields
          if @form[:version].to_i == 3
            %i[name tenant_id user_id password region version]
          else
            %i[name tenant_id username password region version]
          end
        end

        def regions_for(version)
          REGIONS_BY_VERSION.fetch(version.to_i, REGIONS_BY_VERSION[2])
        end

        def field_label(field)
          FIELD_LABELS[field]
        end

        def normalized_form_attrs
          attrs = {
            name:        @form[:name].to_s,
            tenant_id:   @form[:tenant_id].to_s.strip,
            username:    @form[:username].to_s.strip,
            user_id:     @form[:user_id].to_s.strip,
            password:    @form[:password].to_s,
            region:      @form[:region].to_s,
            version:     @form[:version].to_i
          }

          if attrs[:version] == 3
            attrs[:username] = ""
          else
            attrs[:user_id] = ""
          end
          attrs
        end
      end
    end
  end
end
