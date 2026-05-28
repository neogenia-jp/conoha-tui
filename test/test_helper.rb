# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "bundler/setup"
require "minitest/autorun"
require "minitest/reporters"
require "webmock/minitest"
require "mocha/minitest"
require "json"
require "tmpdir"
require "fileutils"

# テスト用に設定ファイルをテンポラリディレクトリに向ける
module ConohaTuiTestHelper
  TEST_TMP_DIR = Dir.mktmpdir("conoha_tui_test")

  def self.setup_temp_dirs!
    stub_const_for_test(
      ConohaTui::Config::Settings, :CONFIG_DIR,
      File.join(TEST_TMP_DIR, "config")
    )
    stub_const_for_test(
      ConohaTui::Config::Settings, :CONFIG_FILE,
      File.join(TEST_TMP_DIR, "config", "config.json")
    )
    stub_const_for_test(
      ConohaTui::Db::Database, :DB_DIR,
      File.join(TEST_TMP_DIR, "db")
    )
    stub_const_for_test(
      ConohaTui::Db::Database, :DB_FILE,
      File.join(TEST_TMP_DIR, "db", "conoha_test.db")
    )
  end

  def self.stub_const_for_test(mod, const_name, value)
    mod.send(:remove_const, const_name) if mod.const_defined?(const_name)
    mod.const_set(const_name, value)
  end

  def self.cleanup!
    FileUtils.rm_rf(TEST_TMP_DIR)
  end
end

require "conoha_tui"

ConohaTuiTestHelper.setup_temp_dirs!

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

# テスト終了時にテンポラリディレクトリを削除する
Minitest.after_run { ConohaTuiTestHelper.cleanup! }

# テスト用ヘルパーメソッド
module Minitest
  class Test
    # テスト用アカウントハッシュを返す
    def test_account_hash(overrides = {})
      {
        "name"        => "テストアカウント",
        "tenant_name" => "test_tenant",
        "username"    => "test_user",
        "password"    => "test_password",
        "region"      => "tyo1",
        "version"     => "2"
      }.merge(overrides)
    end

    # テスト用 Nova サーバーレスポンスを返す
    def test_server_hash(overrides = {})
      {
        "id"     => "aaaabbbb-cccc-dddd-eeee-ffffgggghhh1",
        "name"   => "test-server-01",
        "status" => "ACTIVE",
        "flavor" => { "id" => "g-2gb", "vcpus" => 2, "ram" => 2048 },
        "created" => "2024-01-01T00:00:00Z",
        "updated" => "2024-06-01T00:00:00Z",
        "hostId"  => "host001",
        "tenant_id" => "tenant001",
        "addresses" => {
          "ext-net" => [{ "addr" => "203.0.113.1", "OS-EXT-IPS:type" => "floating" }],
          "int-net" => [{ "addr" => "192.168.0.1", "OS-EXT-IPS:type" => "fixed" }]
        },
        "security_groups" => [{ "name" => "default" }],
        "metadata" => {}
      }.merge(overrides)
    end

    # テスト用 SQLite DB を作成する
    def test_db
      @test_db ||= begin
        db = SQLite3::Database.new(":memory:")
        db.results_as_hash = true
        ConohaTui::Db::Schema.new(db).migrate!
        db
      end
    end
  end
end
