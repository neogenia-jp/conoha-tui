# frozen_string_literal: true

module ConohaTui
  module Api
    # Cinder Volume API クライアント。
    # 追加ディスク（ボリューム）の一覧取得を行う。
    class VolumeClient < BaseClient
      def initialize(auth)
        @auth = auth
        @conn = build_connection(volume_endpoint)
      end

      # ボリューム一覧を詳細付きで取得する
      def list_volumes
        response = get("/volumes/detail")
        response["volumes"] || []
      end

      # ボリューム詳細を取得する
      def get_volume(volume_id)
        response = get("/volumes/#{volume_id}")
        response["volume"]
      end

      private

      def volume_endpoint
        tenant_id = @auth.respond_to?(:tenant_id) ? @auth.tenant_id : @auth.project_id
        base      = @auth.endpoints["volume"] || @auth.endpoints["volumev2"] ||
                    @auth.endpoints["volumev3"]
        raise ApiError, "Volume エンドポイントが見つかりません" unless base

        base.end_with?(tenant_id) ? base : "#{base}/#{tenant_id}"
      end

      def get(path)
        response = @conn.get(path) do |req|
          req.headers["X-Auth-Token"] = @auth.token
        end
        handle_response(response)
      end
    end
  end
end
