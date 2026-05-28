# frozen_string_literal: true

require_relative "../test_helper"

module ConohaTui
  module Api
    class TestAuthV3 < Minitest::Test
      def setup
        account_data = test_account_hash("version" => "3")
        @account     = Config::Account.new(account_data)
        @auth        = AuthV3.new(@account)
      end

      def test_authenticate_success
        stub_request(:post, "https://identity.tyo1.conoha.io/v3/auth/tokens")
          .to_return(
            status: 201,
            headers: {
              "Content-Type"    => "application/json",
              "X-Subject-Token" => "v3_token_abc"
            },
            body: auth_v3_response.to_json
          )

        @auth.authenticate!

        assert_equal "v3_token_abc", @auth.token
        assert_equal "project_id_001", @auth.project_id
        assert_equal "https://compute.tyo1.conoha.io/v2/project_id_001",
                     @auth.endpoints["compute"]
      end

      def test_authenticate_failure_401
        stub_request(:post, "https://identity.tyo1.conoha.io/v3/auth/tokens")
          .to_return(status: 401, body: "")

        assert_raises(BaseClient::AuthError) { @auth.authenticate! }
      end

      def test_token_expired_when_no_auth
        assert @auth.token_expired?
      end

      private

      def auth_v3_response(expires: (Time.now.utc + 3600).iso8601)
        {
          token: {
            expires_at: expires,
            project:    { id: "project_id_001", name: "test_tenant" },
            catalog: [
              {
                type:      "compute",
                endpoints: [
                  { interface: "public", url: "https://compute.tyo1.conoha.io/v2/project_id_001" }
                ]
              },
              {
                type:      "network",
                endpoints: [
                  { interface: "public", url: "https://network.tyo1.conoha.io" }
                ]
              }
            ]
          }
        }
      end
    end
  end
end
