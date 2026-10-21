# frozen_string_literal: true

module ConohaTui
  module Api
    # ConoHa VPS v3 向け Keystone v3 認証クライアント。
    # テナント名 / ユーザー名 / パスワードでトークンを取得する。
    class AuthV3 < BaseClient
      # ConoHa VPS v3 の Identity エンドポイントテンプレート
      ENDPOINT_TEMPLATE = "https://identity.%<region>s.conoha.io"

      attr_reader :token, :project_id, :endpoints

      def initialize(account)
        @account  = account
        @base_url = format(ENDPOINT_TEMPLATE, region: account.region)
        @conn     = build_connection(@base_url)
      end

      # 認証を実行してトークンと各サービスエンドポイントを取得する
      def authenticate!
        auth_payload = {
          identity: {
            methods: ["password"],
            password: {
              user: user_payload
            }
          }
        }
        scope = project_scope
        auth_payload[:scope] = scope if scope

        body = {
          auth: auth_payload
        }

        response = @conn.post("/v3/auth/tokens") do |req|
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end

        unless (200..299).cover?(response.status)
          detail = response.body.is_a?(Hash) ? response.body.to_json : response.body.to_s
          raise AuthError.new("v3 認証エラー (#{response.status}): #{detail}",
                              status: response.status,
                              body: response.body)
        end

        @token = response.headers["x-subject-token"]
        data   = response.body
        parse_token_response!(data)
        self
      end

      def token_expired?
        return true unless @expires_at

        Time.now.utc >= @expires_at
      end

      def ensure_valid_token!
        authenticate! if token_expired?
      end

      private

      def user_payload
        if @account.respond_to?(:user_id) && !@account.user_id.to_s.strip.empty?
          {
            id:       @account.user_id,
            password: @account.password
          }
        else
          {
            name:     @account.username,
            password: @account.password,
            domain:   { id: "default" }
          }
        end
      end

      def project_scope
        tenant = @account.tenant_id.to_s.strip
        return nil if tenant.empty?

        if tenant.match?(/\A[0-9a-f]{32}\z/i)
          { project: { id: tenant } }
        else
          { project: { name: tenant, domain: { id: "default" } } }
        end
      end

      def parse_token_response!(data)
        token_data  = data.fetch("token")
        @project_id = token_data.dig("project", "id")
        @expires_at = parse_time(token_data["expires_at"])
        @endpoints  = parse_catalog(token_data["catalog"] || [])
      end

      def parse_catalog(catalog)
        catalog.each_with_object({}) do |service, hash|
          type      = service["type"]
          endpoints = service["endpoints"] || []
          public_ep = endpoints.find { |e| e["interface"] == "public" }
          hash[type] = public_ep&.fetch("url", nil)
        end
      end

      def parse_time(str)
        return nil unless str

        Time.parse(str).utc
      rescue ArgumentError
        nil
      end
    end
  end
end
