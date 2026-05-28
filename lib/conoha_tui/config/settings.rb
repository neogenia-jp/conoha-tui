# frozen_string_literal: true

require "json"
require "fileutils"

module ConohaTui
  module Config
    # アカウント設定を管理するクラス。
    # 設定は ~/.config/conoha-tui/config.json に保存される。
    class Settings
      CONFIG_DIR  = File.join(Dir.home, ".config", "conoha-tui")
      CONFIG_FILE = File.join(CONFIG_DIR, "config.json")

      DEFAULTS = {
        "accounts"      => [],
        "default_region" => "tyo1"
      }.freeze

      def initialize
        @data = load
      end

      # 設定が空かどうか（初回起動判定に使用）
      def empty?
        @data["accounts"].empty?
      end

      # アカウント一覧を返す
      def accounts
        @data["accounts"].map { |a| Account.new(a) }
      end

      # アカウントを追加する
      def add_account(name:, username:, password:, region:, version:, tenant_name: nil, user_id: nil)
        @data["accounts"] << {
          "name"        => name,
          "tenant_name" => tenant_name,
          "username"    => username,
          "user_id"     => user_id,
          "password"    => password,
          "region"      => region,
          "version"     => version.to_s
        }
        save
      end

      # アカウントを更新する
      def update_account(index, attrs)
        return unless @data["accounts"][index]

        @data["accounts"][index].merge!(attrs.transform_keys(&:to_s))
        save
      end

      # アカウントを削除する
      def delete_account(index)
        @data["accounts"].delete_at(index)
        save
      end

      def default_region
        @data["default_region"]
      end

      def default_region=(region)
        @data["default_region"] = region
        save
      end

      private

      def load
        return DEFAULTS.dup unless File.exist?(CONFIG_FILE)

        JSON.parse(File.read(CONFIG_FILE))
      rescue JSON::ParserError
        DEFAULTS.dup
      end

      def save
        FileUtils.mkdir_p(CONFIG_DIR)
        File.write(CONFIG_FILE, JSON.pretty_generate(@data))
      end
    end

    # 1アカウントの設定を表す値オブジェクト
    class Account
      attr_reader :name, :tenant_name, :username, :user_id, :password, :region, :version

      def initialize(hash)
        @name        = hash["name"]
        @tenant_name = hash["tenant_name"]
        @username    = hash["username"]
        @user_id     = hash["user_id"]
        @password    = hash["password"]
        @region      = hash["region"]
        @version     = hash["version"].to_i
      end

      def v2?
        @version == 2
      end

      def v3?
        @version == 3
      end

      def to_h
        {
          "name"        => @name,
          "tenant_name" => @tenant_name,
          "username"    => @username,
          "user_id"     => @user_id,
          "password"    => @password,
          "region"      => @region,
          "version"     => @version.to_s
        }
      end
    end
  end
end
