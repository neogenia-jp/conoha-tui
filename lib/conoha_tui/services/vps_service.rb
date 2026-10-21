# frozen_string_literal: true

module ConohaTui
  module Services
    # VPS 操作のビジネスロジックを担うサービスクラス。
    # API クライアントとリポジトリを協調させて VPS の取得・操作を行う。
    class VpsService
      include AccountRefresh

      SORT_FIELDS = %i[name created_at contract_end_at].freeze

      def initialize(settings)
        @settings   = settings
        @vps_repo   = Db::Repositories::VpsRepository.new
      end

      # キャッシュ（SQLite）から VPS 一覧を返す
      # @param sort_by [Symbol] ソートフィールド (:name, :created_at, :contract_end_at)
      # @param sort_order [Symbol] :asc または :desc
      # @param filter [String, nil] 名前・ホストの部分一致フィルタ
      def list(sort_by: :name, sort_order: :asc, filter: nil)
        vpses = filter ? @vps_repo.search(filter) : @vps_repo.all
        sort_vpses(vpses, sort_by, sort_order)
      end

      # ID で VPS を取得する
      def find(id)
        @vps_repo.find(id)
      end

      # 全アカウントの VPS を API から再取得してキャッシュを更新する
      # @yield [String] 進捗メッセージ
      # @return [Array] 失敗したアカウントの [アカウント名, エラーメッセージ]
      def refresh_all(&on_progress)
        each_account_collecting_errors do |account|
          refresh_account(account, &on_progress)
        end
      end

      # 指定アカウントの VPS を API から再取得してキャッシュを更新する
      def refresh_account(account)
        yield "#{account.name} (#{account.region}) に接続中..." if block_given?

        auth    = build_auth(account)
        compute = Api::ComputeClient.new(auth)
        servers = compute.list_servers
        enrich_servers_with_flavor_specs!(compute, servers)

        # VPS v2 の場合は割引切符情報も取得する
        tickets = fetch_discount_tickets(account, auth)

        vpses = servers.map do |server|
          vps = Models::Vps.from_api(server,
                                     account_name: account.name,
                                     region:       account.region,
                                     vps_version:  account.version)
          if (ticket = tickets[server["id"]])
            vps.discount_ticket = ticket["name"] || ticket["id"]
            vps.contract_end_at ||= ticket_contract_end_at(ticket)
          end
          vps
        end

        # 既存キャッシュを削除して新しいデータで置き換える
        @vps_repo.delete_by_account(account.name, account.region)
        @vps_repo.upsert_all(vpses)

        yield "#{account.name}: #{vpses.size} 台取得完了" if block_given?
        vpses
      end

      # 電源を ON にする
      def start(vps)
        account = find_account(vps.account_name)
        raise "アカウント '#{vps.account_name}' が見つかりません" unless account

        auth    = build_auth(account)
        compute = Api::ComputeClient.new(auth)
        compute.start_server(vps.id)
        vps.status = Models::Vps::POWER_STATUS_ON
        @vps_repo.upsert(vps)
      end

      # 電源を OFF にする
      def stop(vps)
        account = find_account(vps.account_name)
        raise "アカウント '#{vps.account_name}' が見つかりません" unless account

        auth    = build_auth(account)
        compute = Api::ComputeClient.new(auth)
        compute.stop_server(vps.id)
        vps.status = Models::Vps::POWER_STATUS_OFF
        @vps_repo.upsert(vps)
      end

      # VPS 詳細を API から再取得する
      def refresh_vps(vps)
        account = find_account(vps.account_name)
        raise "アカウント '#{vps.account_name}' が見つかりません" unless account

        auth   = build_auth(account)
        compute = Api::ComputeClient.new(auth)
        server = compute.get_server(vps.id)
        enrich_servers_with_flavor_specs!(compute, [server])
        updated = Models::Vps.from_api(server,
                                       account_name: account.name,
                                       region:       account.region,
                                       vps_version:  account.version)
        updated.discount_ticket = vps.discount_ticket
        @vps_repo.upsert(updated)
        updated
      end

      private

      def sort_vpses(vpses, sort_by, sort_order)
        sorted = vpses.sort_by do |v|
          case sort_by
          when :name_tag     then v.metadata['instance_name_tag'].to_s.downcase
          when :name         then v.name.to_s.downcase
          when :created_at   then v.created_at || Time.at(0)
          when :contract_end_at then v.contract_end_at || Time.at(0)
          else v.name.to_s.downcase
          end
        end
        sort_order == :desc ? sorted.reverse : sorted
      end

      def build_auth(account)
        auth = account.v3? ? Api::AuthV3.new(account) : Api::AuthV2.new(account)
        auth.authenticate!
      end

      def find_account(name)
        @settings.accounts.find { |a| a.name == name }
      end

      def fetch_discount_tickets(account, auth)
        return {} unless account.v2?

        client  = Api::DiscountTicketClient.new(auth)
        tickets = client.list_discount_tickets
        tickets.each_with_object({}) { |t, h| h[t["instance_id"]] = t }
      rescue Api::BaseClient::ApiError
        {}
      end

      def enrich_servers_with_flavor_specs!(compute, servers)
        flavor_cache = {}

        servers.each do |server|
          next unless server.is_a?(Hash)

          flavor_id = server.dig("flavor", "id") || server["flavor_id"] || server["flavorId"]
          next if flavor_id.to_s.strip.empty?

          flavor = flavor_cache[flavor_id]
          unless flavor
            flavor = compute.get_flavor(flavor_id)
            flavor_cache[flavor_id] = flavor
          end
          next unless flavor.is_a?(Hash)

          server["flavor"] ||= {}
          server["flavor"]["vcpus"] ||= flavor["vcpus"]
          server["flavor"]["ram"]   ||= flavor["ram"]
        rescue Api::BaseClient::ApiError
          next
        end
      end

      def ticket_contract_end_at(ticket)
        keys = %w[contract_end_at contract_end end_at end_date expire_at expires_at expiration_date]
        keys.each do |key|
          value = ticket[key]
          next if value.to_s.strip.empty?

          begin
            return Time.parse(value).utc
          rescue ArgumentError, TypeError
            next
          end
        end
        nil
      end
    end
  end
end
