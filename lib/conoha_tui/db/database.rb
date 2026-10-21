# frozen_string_literal: true

require "sqlite3"
require "fileutils"
require "singleton"

module ConohaTui
  module Db
    # SQLite データベース接続を管理するシングルトンクラス。
    class Database
      include Singleton

      DB_DIR  = File.join(Dir.home, ".config", "conoha-tui")
      DB_FILE = File.join(DB_DIR, "conoha.db")

      def initialize
        FileUtils.mkdir_p(DB_DIR)
        @conn = SQLite3::Database.new(DB_FILE)
        @conn.results_as_hash = true
        @conn.execute("PRAGMA journal_mode=WAL")
        @conn.execute("PRAGMA foreign_keys=ON")
        Schema.new(@conn).migrate!
      end

      # データベース接続を返す
      def conn
        @conn
      end

      # トランザクションを実行する
      def transaction(&block)
        @conn.transaction(&block)
      end

      # シングルトン経由でアクセスするショートカット
      def self.conn
        instance.conn
      end

      def self.transaction(&block)
        instance.transaction(&block)
      end
    end
  end
end
