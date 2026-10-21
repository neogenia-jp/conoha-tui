# frozen_string_literal: true

require_relative "../test_helper"

module ConohaTui
  module Config
    class TestSettings < Minitest::Test
      def setup
        # テスト用にインスタンス変数で設定を初期化する
        @settings = Settings.new
        @settings.instance_variable_set(:@data, {
          "accounts"       => [],
          "default_region" => "tyo1"
        })
      end

      def test_empty_returns_true_when_no_accounts
        assert @settings.empty?
      end

      def test_empty_returns_false_when_accounts_exist
        @settings.add_account(
          name: "テスト", tenant_id: "t", username: "u",
          password: "p", region: "tyo1", version: 2
        )
        refute @settings.empty?
      end

      def test_add_account
        @settings.add_account(
          name: "本番",   tenant_id: "prod_tenant",
          username: "prod_user", password: "prod_pass",
          region: "tyo2", version: 3
        )

        accounts = @settings.accounts
        assert_equal 1, accounts.size
        assert_equal "本番",        accounts.first.name
        assert_equal "prod_tenant", accounts.first.tenant_id
        assert_equal "tyo2",        accounts.first.region
        assert_equal 3,             accounts.first.version
      end

      def test_update_account
        @settings.add_account(
          name: "旧名前", tenant_id: "t", username: "u",
          password: "p", region: "tyo1", version: 2
        )

        @settings.update_account(0, { "name" => "新名前" })
        assert_equal "新名前", @settings.accounts.first.name
      end

      def test_delete_account
        @settings.add_account(
          name: "削除対象", tenant_id: "t", username: "u",
          password: "p", region: "tyo1", version: 2
        )
        @settings.delete_account(0)
        assert_empty @settings.accounts
      end

      def test_account_v2?
        account = Account.new(test_account_hash("version" => "2"))
        assert account.v2?
        refute account.v3?
      end

      def test_account_v3?
        account = Account.new(test_account_hash("version" => "3"))
        assert account.v3?
        refute account.v2?
      end

      def test_account_to_h
        hash    = test_account_hash
        account = Account.new(hash)
        result  = account.to_h

        assert_equal hash["name"],        result["name"]
        assert_equal hash["tenant_id"], result["tenant_id"]
        assert_equal hash["region"],      result["region"]
        assert_equal hash["version"],     result["version"]
      end
    end
  end
end
