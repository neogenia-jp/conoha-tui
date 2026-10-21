# frozen_string_literal: true

module ConohaTui
  module Api
    # ConoHa VPS v2 向け Keystone v2.0 認証クライアント。
    # テナント名 / ユーザー名 / パスワードでトークンを取得する。
    class AuthV2 < BaseClient
      # ConoHa VPS v2 の Identity エンドポイントテンプレート
      ENDPOINT_TEMPLATE = "https://identity.%<region>s.conoha.io"

      attr_reader :token, :tenant_id, :endpoints

      def initialize(account)
        @account  = account
        @base_url = format(ENDPOINT_TEMPLATE, region: account.region)
        @conn     = build_connection(@base_url)
      end

      # 認証を実行してトークンと各サービスエンドポイントを取得する
      def authenticate!
        tenant_scope = initial_tenant_scope
        data = request_token(tenant_scope: tenant_scope)
        parse_token_response!(data)

        # tenant 未指定時は unscoped token が返る場合があり、catalog が空になる。
        # その場合は tenant 一覧から解決して scoped token を取り直す。
        unless compute_endpoint_available?
          scoped_tenant_id = resolve_tenant_id
          if scoped_tenant_id && scoped_tenant_id != @tenant_id
            data = request_token(tenant_scope: scoped_tenant_id)
            parse_token_response!(data)
          end
        end

        self
      end

      # トークンの有効期限切れをチェックする
      def token_expired?
        return true unless @expires_at

        Time.now.utc >= @expires_at
      end

      # 期限切れの場合は再認証する
      def ensure_valid_token!
        authenticate! if token_expired?
      end

      private

      def initial_tenant_scope
        tenant = @account.tenant_name.to_s.strip
        return tenant unless tenant.empty?

        tenant_from_cli_config || ""
      end

      def request_token(tenant_scope:)
        auth_body = {
          passwordCredentials: {
            username: @account.username,
            password: @account.password
          }
        }

        tenant = tenant_scope.to_s.strip
        unless tenant.empty?
          if tenant.match?(/\A[0-9a-f]{32}\z/i)
            auth_body[:tenantId] = tenant
          else
            auth_body[:tenantName] = tenant
          end
        end

        response = @conn.post("/v2.0/tokens") do |req|
          req.headers["Content-Type"] = "application/json"
          req.body = { auth: auth_body }.to_json
        end
        unless (200..299).cover?(response.status)
          detail = response.body.is_a?(Hash) ? response.body.dig("error", "message") : response.body
          raise AuthError.new("v2 認証エラー (#{response.status}): #{detail}",
                              status: response.status, body: response.body)
        end
        response.body
      end

      def resolve_tenant_id
        tenant = @account.tenant_name.to_s.strip
        return tenant if tenant.match?(/\A[0-9a-f]{32}\z/i)
        return tenant_from_cli_config if tenant.empty? && tenant_from_cli_config
        return nil unless @token

        response = @conn.get("/v2.0/tenants") do |req|
          req.headers["X-Auth-Token"] = @token
        end
        data = handle_response(response)
        tenants = data["tenants"] || []
        return tenants.first&.fetch("id", nil) if tenant.empty?

        tenants.find { |t| t["name"].to_s == tenant }&.fetch("id", nil)
      rescue ApiError
        nil
      end

      def compute_endpoint_available?
        @endpoints["compute"] || @endpoints["nova"]
      end

      def tenant_from_cli_config
        path = File.join(Dir.home, ".conoha", "config")
        return nil unless File.file?(path)

        data = parse_simple_kv_config(path)
        username = data["username"].to_s.strip
        region   = data["region"].to_s.strip
        tenant   = data["tenant_id"].to_s.strip

        return nil if tenant.empty?
        return nil unless username.empty? || username == @account.username.to_s.strip
        return nil unless region.empty? || region == @account.region.to_s.strip

        tenant
      rescue StandardError
        nil
      end

      def parse_simple_kv_config(path)
        pairs = {}
        File.readlines(path, chomp: true).each do |line|
          next if line.strip.empty? || line.strip.start_with?("#", ";", "[")
          next unless line.include?("=")

          key, value = line.split("=", 2)
          pairs[key.to_s.strip] = value.to_s.strip.gsub(/\A\"|\"\z/, "")
        end
        pairs
      end

      def parse_token_response!(data)
        access      = data.fetch("access")
        token_data  = access.fetch("token")

        @token      = token_data.fetch("id")
        @tenant_id  = token_data.dig("tenant", "id")
        @expires_at = parse_time(token_data["expires"])
        @endpoints  = parse_service_catalog(access["serviceCatalog"] || [])
      end

      def parse_service_catalog(catalog)
        catalog.each_with_object({}) do |service, hash|
          type = service["type"]
          endpoints = service["endpoints"] || []
          hash[type] = endpoints.first&.fetch("publicURL", nil)
          hash["compute"] = hash[type] if type.to_s.start_with?("compute") && hash["compute"].nil?
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
