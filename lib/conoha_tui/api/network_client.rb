# frozen_string_literal: true

module ConohaTui
  module Api
    # Neutron Network API クライアント。
    # ネットワーク・ポート・セキュリティグループを管理する。
    class NetworkClient < BaseClient
      def initialize(auth)
        @auth = auth
        @conn = build_connection(network_endpoint)
      end

      # ネットワーク一覧を取得する
      def list_networks
        response = get("/v2.0/networks")
        response["networks"] || []
      end

      # ポート一覧を取得する（サーバーIDでフィルタ可能）
      # @param server_id [String, nil] フィルタするサーバーID
      def list_ports(server_id: nil)
        path = "/v2.0/ports"
        path += "?device_id=#{server_id}" if server_id
        response = get(path)
        response["ports"] || []
      end

      # セキュリティグループ一覧を取得する
      def list_security_groups
        response = get("/v2.0/security-groups")
        response["security_groups"] || []
      end

      # セキュリティグループ詳細を取得する
      def get_security_group(sg_id)
        response = get("/v2.0/security-groups/#{sg_id}")
        response["security_group"]
      end

      # セキュリティグループルールを追加する（ポートを開放する）
      # @param sg_id [String] セキュリティグループID
      # @param protocol [String] "tcp", "udp", "icmp"
      # @param port_range_min [Integer] 開始ポート
      # @param port_range_max [Integer] 終了ポート
      # @param direction [String] "ingress" or "egress"
      def create_security_group_rule(sg_id:, protocol:, port_range_min:, port_range_max:,
                                     direction: "ingress", remote_ip_prefix: "0.0.0.0/0")
        body = {
          security_group_rule: {
            security_group_id: sg_id,
            protocol:          protocol,
            port_range_min:    port_range_min,
            port_range_max:    port_range_max,
            direction:         direction,
            remote_ip_prefix:  remote_ip_prefix,
            ethertype:         "IPv4"
          }
        }
        response = post("/v2.0/security-group-rules", body)
        response["security_group_rule"]
      end

      # セキュリティグループルールを削除する（ポートをクローズする）
      # @param rule_id [String] ルールID
      def delete_security_group_rule(rule_id)
        @conn.delete("/v2.0/security-group-rules/#{rule_id}") do |req|
          req.headers["X-Auth-Token"] = @auth.token
        end
      end

      # フローティングIP一覧を取得する
      def list_floating_ips
        response = get("/v2.0/floatingips")
        response["floatingips"] || []
      end

      private

      def network_endpoint
        base = @auth.endpoints["network"] || @auth.endpoints["neutron"]
        raise ApiError, "Network エンドポイントが見つかりません" unless base

        base
      end

      def get(path)
        response = @conn.get(path) do |req|
          req.headers["X-Auth-Token"] = @auth.token
        end
        handle_response(response)
      end

      def post(path, body)
        response = @conn.post(path) do |req|
          req.headers["X-Auth-Token"] = @auth.token
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end
        handle_response(response)
      end
    end
  end
end
