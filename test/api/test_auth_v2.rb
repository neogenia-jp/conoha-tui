# frozen_string_literal: true

require_relative "../test_helper"

module ConohaTui
  module Api
    class TestAuthV2 < Minitest::Test
      def setup
        @account = Config::Account.new(test_account_hash)
        @auth    = AuthV2.new(@account)
      end

      def test_authenticate_success
        stub_request(:post, "https://identity.tyo1.conoha.io/v2.0/tokens")
          .with(
            body: hash_including(
              auth: {
                tenantName:          "test_tenant",
                passwordCredentials: { username: "test_user", password: "test_password" }
              }
            )
          )
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: auth_v2_response.to_json
          )

        @auth.authenticate!

        assert_equal "test_token_123", @auth.token
        assert_equal "tenant_id_001", @auth.tenant_id
        assert_equal "https://compute.tyo1.conoha.io/v2/tenant_id_001",
                     @auth.endpoints["compute"]
      end

      def test_authenticate_failure_401
        stub_request(:post, "https://identity.tyo1.conoha.io/v2.0/tokens")
          .to_return(status: 401, body: { error: "Unauthorized" }.to_json)

        assert_raises(BaseClient::AuthError) { @auth.authenticate! }
      end

      def test_token_not_expired
        stub_request(:post, "https://identity.tyo1.conoha.io/v2.0/tokens")
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: auth_v2_response.to_json
          )

        @auth.authenticate!
        refute @auth.token_expired?
      end

      def test_ensure_valid_token_reauthenticates_when_expired
        # 同一URLに複数スタブを定義すると後勝ちになるため、
        # 1つのスタブで連続するレスポンスを配列で指定する
        expired_body = auth_v2_response(expires: (Time.now.utc - 3600).iso8601).to_json
        fresh_body   = auth_v2_response.to_json
        stub_request(:post, "https://identity.tyo1.conoha.io/v2.0/tokens")
          .to_return(
            [
              { status: 200, headers: { "Content-Type" => "application/json" }, body: expired_body },
              { status: 200, headers: { "Content-Type" => "application/json" }, body: fresh_body }
            ]
          )

        @auth.authenticate!
        assert @auth.token_expired?

        @auth.ensure_valid_token!
        refute @auth.token_expired?
      end

      private

      def auth_v2_response(expires: (Time.now.utc + 3600).iso8601)
        {
          access: {
            token: {
              id:      "test_token_123",
              expires: expires,
              tenant:  { id: "tenant_id_001", name: "test_tenant" }
            },
            serviceCatalog: [
              {
                type:      "compute",
                endpoints: [{ publicURL: "https://compute.tyo1.conoha.io/v2/tenant_id_001" }]
              },
              {
                type:      "network",
                endpoints: [{ publicURL: "https://network.tyo1.conoha.io" }]
              }
            ]
          }
        }
      end
    end
  end
end
