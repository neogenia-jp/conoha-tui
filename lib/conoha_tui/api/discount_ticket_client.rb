# frozen_string_literal: true

module ConohaTui
  module Api
    # ConoHa VPS v2 専用の割引切符 API クライアント。
    # 割引切符は VPS v2 にのみ存在する ConoHa 独自機能。
    class DiscountTicketClient < BaseClient
      # ConoHa 割引切符 API エンドポイントテンプレート
      ENDPOINT_TEMPLATE = "https://account.tyo1.conoha.io/v1/%<tenant_id>s"

      def initialize(auth)
        @auth      = auth
        @tenant_id = auth.respond_to?(:tenant_id) ? auth.tenant_id : auth.project_id
        @conn      = build_connection(format(ENDPOINT_TEMPLATE, tenant_id: @tenant_id))
      end

      # 割引切符一覧を取得する
      # @return [Array<Hash>] 割引切符情報
      def list_discount_tickets
        response = @conn.get("/discount-tickets") do |req|
          req.headers["X-Auth-Token"] = @auth.token
          req.headers["Accept"]       = "application/json"
        end
        data = handle_response(response)
        data["discount_tickets"] || []
      rescue ApiError
        # 割引切符 API は VPS v3 では利用不可のためエラーを無視
        []
      end

      # 特定サーバーに割り当てられた割引切符を取得する
      # @param server_id [String] サーバーID
      # @return [Hash, nil] 割引切符情報
      def get_server_discount_ticket(server_id)
        tickets = list_discount_tickets
        tickets.find { |t| t["instance_id"] == server_id }
      end
    end
  end
end
