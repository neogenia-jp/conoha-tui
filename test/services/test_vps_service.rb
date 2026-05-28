# frozen_string_literal: true

require_relative "../test_helper"

module ConohaTui
  module Services
    class TestVpsService < Minitest::Test
      def setup
        @settings = Config::Settings.new
        # テスト用に一時ファイルを使うので既存設定はクリア
        @settings.instance_variable_set(:@data, {
          "accounts"       => [test_account_hash],
          "default_region" => "tyo1"
        })

        @service = VpsService.new(@settings)
        @repo    = Db::Repositories::VpsRepository.new(test_db)
        # サービスに test_db を使わせるためリポジトリを差し替える
        @service.instance_variable_set(:@vps_repo, @repo)
      end

      def test_list_returns_vpses_from_cache
        insert_sample_vps("server-a")
        insert_sample_vps("server-b", id: "id-002")

        vpses = @service.list
        assert_equal 2, vpses.size
      end

      def test_list_sorts_by_name_asc
        insert_sample_vps("zebra-server", id: "id-001")
        insert_sample_vps("apple-server", id: "id-002")

        vpses = @service.list(sort_by: :name, sort_order: :asc)
        assert_equal "apple-server", vpses.first.name
        assert_equal "zebra-server", vpses.last.name
      end

      def test_list_sorts_by_name_desc
        insert_sample_vps("zebra-server", id: "id-001")
        insert_sample_vps("apple-server", id: "id-002")

        vpses = @service.list(sort_by: :name, sort_order: :desc)
        assert_equal "zebra-server", vpses.first.name
      end

      def test_list_filters_by_name
        insert_sample_vps("web-server", id: "id-001")
        insert_sample_vps("db-server",  id: "id-002")

        vpses = @service.list(filter: "web")
        assert_equal 1, vpses.size
        assert_equal "web-server", vpses.first.name
      end

      def test_find_returns_vps
        insert_sample_vps("my-server")
        vps = @service.find("test-vps-id-001")
        refute_nil vps
        assert_equal "my-server", vps.name
      end

      def test_find_returns_nil_for_unknown_id
        assert_nil @service.find("nonexistent-id")
      end

      def test_refresh_all_calls_api_and_saves_to_db
        stub_auth_request
        stub_compute_request([test_server_hash])

        # 割引切符 API（v2）
        stub_request(:get, /discount-tickets/)
          .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                     body: { discount_tickets: [] }.to_json)

        @service.refresh_all
        vpses = @service.list
        assert_equal 1, vpses.size
        assert_equal "test-server-01", vpses.first.name
      end

      private

      def insert_sample_vps(name, id: "test-vps-id-001")
        vps = Models::Vps.new(
          id: id, name: name, status: "ACTIVE",
          vcpus: 2, ram: 2048, account_name: "テストアカウント",
          region: "tyo1", vps_version: 2
        )
        @repo.upsert(vps)
      end

      def stub_auth_request
        stub_request(:post, "https://identity.tyo1.conoha.io/v2.0/tokens")
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: {
              access: {
                token: {
                  id:      "tok123",
                  expires: (Time.now.utc + 3600).iso8601,
                  tenant:  { id: "tenant001", name: "test_tenant" }
                },
                serviceCatalog: [
                  {
                    type:      "compute",
                    endpoints: [{ publicURL: "https://compute.tyo1.conoha.io/v2/tenant001" }]
                  }
                ]
              }
            }.to_json
          )
      end

      def stub_compute_request(servers)
        stub_request(:get, "https://compute.tyo1.conoha.io/v2/tenant001/servers/detail")
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: { servers: servers }.to_json
          )
      end
    end
  end
end
