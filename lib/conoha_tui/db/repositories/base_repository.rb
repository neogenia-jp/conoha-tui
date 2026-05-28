# frozen_string_literal: true

module ConohaTui
  module Db
    module Repositories
      # すべてのリポジトリの基底クラス。
      # SQLite の共通操作を提供する。
      class BaseRepository
        def initialize(db = Database.conn)
          @db = db
        end

        protected

        def now_iso8601
          Time.now.utc.iso8601
        end

        # 配列をプレースホルダー文字列に変換 ("?, ?, ?" など)
        def placeholders(arr)
          Array.new(arr.size, "?").join(", ")
        end
      end
    end
  end
end
