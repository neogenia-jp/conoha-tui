# frozen_string_literal: true

module ConohaTui
  module Api
    # Nova Compute API クライアント。
    # サーバー（VPS）の一覧取得・電源操作を行う。
    class ComputeClient < BaseClient
      def initialize(auth)
        @auth = auth
        @conn = build_connection(compute_endpoint)
      end

      # サーバー一覧を詳細付きで取得する
      # @return [Array<Hash>] サーバー情報のハッシュ配列
      def list_servers
        response = get("/servers/detail")
        (response["servers"] || [])
      end

      # サーバー詳細を取得する
      # @param server_id [String] サーバーID
      # @return [Hash] サーバー情報
      def get_server(server_id)
        response = get("/servers/#{server_id}")
        response["server"]
      end

      # フレーバー詳細を取得する
      # @param flavor_id [String] フレーバーID
      # @return [Hash, nil] フレーバー情報
      def get_flavor(flavor_id)
        response = get("/flavors/#{flavor_id}")
        response["flavor"]
      end

      # 電源をONにする (os-start)
      # @param server_id [String] サーバーID
      def start_server(server_id)
        post("/servers/#{server_id}/action", { "os-start": nil })
      end

      # 電源をOFFにする (os-stop)
      # @param server_id [String] サーバーID
      def stop_server(server_id)
        post("/servers/#{server_id}/action", { "os-stop": nil })
      end

      # 再起動する (reboot)
      # @param server_id [String] サーバーID
      # @param type [String] "SOFT" または "HARD"
      def reboot_server(server_id, type: "SOFT")
        post("/servers/#{server_id}/action", { reboot: { type: type } })
      end

      # サーバーの収容ホスト情報を含む詳細を取得する
      # （管理者権限が必要な場合がある）
      def get_server_diagnostics(server_id)
        response = get("/servers/#{server_id}/diagnostics")
        response
      end

      private

      def compute_endpoint
        tenant_id = @auth.respond_to?(:tenant_id) ? @auth.tenant_id : @auth.project_id
        base      = @auth.endpoints["compute"] || @auth.endpoints["nova"]
        unless base
          raise ApiError,
                "Compute エンドポイントが見つかりません (tenant_id=#{tenant_id || '-'} " \
                "catalog_keys=#{@auth.endpoints.keys.join(',')})"
        end

        # v2 はエンドポイントに tenant_id が含まれない場合は付加する。
        # v3 のカタログ (例: .../v2.1) はそのまま使う。
        url = @auth.respond_to?(:tenant_id) && !base.end_with?(tenant_id) ? "#{base}/#{tenant_id}" : base
        # Faraday の相対パス結合のため末尾スラッシュを保証する
        url.end_with?("/") ? url : "#{url}/"
      end

      def get(path)
        # 先頭スラッシュはホスト相対パスになるため除去して相対パスにする
        response = @conn.get(path.delete_prefix("/")) do |req|
          req.headers["X-Auth-Token"] = @auth.token
        end
        handle_response(response)
      end

      def post(path, body)
        response = @conn.post(path.delete_prefix("/")) do |req|
          req.headers["X-Auth-Token"] = @auth.token
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end
        handle_response(response)
      end
    end
  end
end
