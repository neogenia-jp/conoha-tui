# frozen_string_literal: true

module ConohaTui
  module Services
    # ネットワーク・ポート操作のビジネスロジックを担うサービスクラス。
    class NetworkService
      def initialize(settings)
        @settings     = settings
        @network_repo = Db::Repositories::NetworkRepository.new
        @port_repo    = Db::Repositories::PortRepository.new
      end

      # キャッシュからネットワーク一覧を返す
      def list_networks
        @network_repo.all
      end

      # キャッシュからポート一覧を返す（サーバーIDでフィルタ可能）
      def list_ports(server_id: nil)
        server_id ? @port_repo.by_server(server_id) : []
      end

      # 全アカウントのネットワーク情報を API から再取得する
      def refresh_all
        @settings.accounts.each do |account|
          refresh_account(account)
          yield account.name if block_given?
        end
      end

      # 指定アカウントのネットワーク・ポート情報を再取得する
      def refresh_account(account)
        auth   = build_auth(account)
        net_cl = Api::NetworkClient.new(auth)

        # ネットワーク一覧
        networks = net_cl.list_networks.map do |data|
          Models::Network.from_api(data, account_name: account.name, region: account.region)
        end

        # ポート一覧を取得して接続VPSとの紐付けを行う
        ports_data = net_cl.list_ports
        sg_list    = net_cl.list_security_groups

        # ネットワークと接続VPSを関連付ける
        associate_networks_with_servers!(networks, ports_data)

        @network_repo.delete_by_account(account.name, account.region)
        @network_repo.upsert_all(networks)

        # セキュリティグループルールをポートとして保存する
        all_ports = build_ports_from_security_groups(sg_list, ports_data, account)
        @port_repo.delete_by_account(account.name, account.region)
        @port_repo.upsert_all(all_ports)
      end

      # ポートを開放する（セキュリティグループルールを追加する）
      def open_port(vps:, protocol:, port:, remote_ip_prefix: "0.0.0.0/0")
        account = find_account(vps.account_name)
        raise "アカウント '#{vps.account_name}' が見つかりません" unless account

        auth   = build_auth(account)
        net_cl = Api::NetworkClient.new(auth)

        # VPS に紐付くセキュリティグループを取得する
        sg_name = vps.security_groups.first
        raise "セキュリティグループが見つかりません" unless sg_name

        sg_list = net_cl.list_security_groups
        sg      = sg_list.find { |s| s["name"] == sg_name }
        raise "セキュリティグループ '#{sg_name}' が見つかりません" unless sg

        rule = net_cl.create_security_group_rule(
          sg_id:            sg["id"],
          protocol:         protocol,
          port_range_min:   port,
          port_range_max:   port,
          remote_ip_prefix: remote_ip_prefix
        )

        # キャッシュに追加する
        port_model = Models::Port.from_api_rule(rule, sg_id: sg["id"],
                                                      sg_name: sg_name,
                                                      account_name: account.name,
                                                      region: account.region)
        port_model.server_id = vps.id
        @port_repo.upsert(port_model)
        port_model
      end

      # ポートをクローズする（セキュリティグループルールを削除する）
      def close_port(port, vps:)
        account = find_account(vps.account_name)
        raise "アカウント '#{vps.account_name}' が見つかりません" unless account

        auth   = build_auth(account)
        net_cl = Api::NetworkClient.new(auth)
        net_cl.delete_security_group_rule(port.rule_id)

        @port_repo.delete_by_security_group(port.sg_id)
        # 当該アカウントのポートを再取得してキャッシュを更新する
        refresh_account(account)
      end

      private

      def build_auth(account)
        auth = Api::AuthV2.new(account)
        auth.authenticate!
      end

      def find_account(name)
        @settings.accounts.find { |a| a.name == name }
      end

      def associate_networks_with_servers!(networks, ports_data)
        # ネットワークID → 接続サーバーIDのマップを構築する
        net_server_map = Hash.new { |h, k| h[k] = [] }
        ports_data.each do |port|
          next unless port["device_id"] && !port["device_id"].empty?

          (port["fixed_ips"] || []).each do |ip|
            net_server_map[ip["subnet_id"]] << port["device_id"]
          end
        end

        networks.each do |network|
          server_ids = network.subnets.flat_map { |s| net_server_map[s] }.uniq
          network.connected_server_ids = server_ids
        end
      end

      def build_ports_from_security_groups(sg_list, ports_data, account)
        # ポートデータからセキュリティグループとサーバーIDのマップを作成する
        sg_server_map = {}
        ports_data.each do |port|
          (port["security_groups"] || []).each do |sg_id|
            sg_server_map[sg_id] = port["device_id"]
          end
        end

        sg_list.flat_map do |sg|
          server_id = sg_server_map[sg["id"]]
          (sg["security_group_rules"] || []).map do |rule|
            p = Models::Port.from_api_rule(rule, sg_id: sg["id"],
                                                 sg_name: sg["name"],
                                                 account_name: account.name,
                                                 region: account.region)
            p.server_id = server_id
            p
          end
        end
      end
    end
  end
end
