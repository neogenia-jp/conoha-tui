# frozen_string_literal: true

require_relative "../test_helper"

module ConohaTui
  module Api
    class TestComputeClient < Minitest::Test
      def setup
        @auth = mock_auth
        @client = ComputeClient.new(@auth)
      end

      def test_list_servers
        stub_request(:get, "https://compute.tyo1.conoha.io/v2/tenant_id_001/servers/detail")
          .with(headers: { "X-Auth-Token" => "test_token" })
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: { servers: [test_server_hash] }.to_json
          )

        servers = @client.list_servers
        assert_equal 1, servers.size
        assert_equal "test-server-01", servers.first["name"]
      end

      def test_list_servers_returns_empty_on_no_results
        stub_request(:get, "https://compute.tyo1.conoha.io/v2/tenant_id_001/servers/detail")
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: { servers: [] }.to_json
          )

        assert_empty @client.list_servers
      end

      def test_start_server
        server_id = "aaaa-bbbb-cccc"
        stub_request(:post, "https://compute.tyo1.conoha.io/v2/tenant_id_001/servers/#{server_id}/action")
          .with(body: hash_including("os-start": nil))
          .to_return(status: 202, body: "")

        # 202 は空ボディ — handle_response が正常終了することを確認
        @client.start_server(server_id)
      end

      def test_stop_server
        server_id = "aaaa-bbbb-cccc"
        stub_request(:post, "https://compute.tyo1.conoha.io/v2/tenant_id_001/servers/#{server_id}/action")
          .with(body: hash_including("os-stop": nil))
          .to_return(status: 202, body: "")

        @client.stop_server(server_id)
      end

      def test_raises_auth_error_on_401
        stub_request(:get, "https://compute.tyo1.conoha.io/v2/tenant_id_001/servers/detail")
          .to_return(status: 401, body: "")

        assert_raises(BaseClient::AuthError) { @client.list_servers }
      end

      def test_raises_server_error_on_500
        stub_request(:get, "https://compute.tyo1.conoha.io/v2/tenant_id_001/servers/detail")
          .to_return(status: 500, body: "Internal Server Error")

        assert_raises(BaseClient::ServerError) { @client.list_servers }
      end

      private

      def mock_auth
        auth = Minitest::Mock.new
        auth.expect(:token,     "test_token")
        auth.expect(:tenant_id, "tenant_id_001")
        auth.expect(:endpoints, {
          "compute" => "https://compute.tyo1.conoha.io/v2/tenant_id_001"
        })
        # ComputeClient のコンストラクタで呼ばれる分
        auth.expect(:respond_to?, true, [:tenant_id])
        auth
      end
    end
  end
end
