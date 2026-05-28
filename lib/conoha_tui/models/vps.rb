# frozen_string_literal: true

module ConohaTui
  module Models
    # VPS（仮想プライベートサーバー）を表すモデル。
    # ConoHa VPS v2 / v3 の両方に対応する。
    class Vps
      POWER_STATUS_ON  = "ACTIVE"
      POWER_STATUS_OFF = "SHUTOFF"

      attr_accessor :id, :name, :status, :vcpus, :ram, :flavor_id,
                    :created_at, :updated_at, :host_id, :tenant_id,
                    :addresses, :security_groups, :metadata,
                    :contract_end_at, :discount_ticket,
                    :account_name, :region, :vps_version

      def initialize(attrs = {})
        attrs.each { |k, v| public_send(:"#{k}=", v) if respond_to?(:"#{k}=") }
      end

      # API レスポンス（Nova サーバー詳細）からモデルを生成する
      # @param data [Hash] Nova API のサーバーハッシュ
      # @param account_name [String] アカウント識別名
      # @param region [String] リージョン
      # @param vps_version [Integer] VPS バージョン (2 or 3)
      def self.from_api(data, account_name:, region:, vps_version:)
        metadata = data["metadata"] || {}
        new(
          id:             data["id"],
          name:           extract_name(data, metadata),
          status:         data["status"],
          vcpus:          extract_vcpus(data),
          ram:            extract_ram(data),
          flavor_id:      data.dig("flavor", "id"),
          created_at:     parse_time(data["created"]),
          updated_at:     parse_time(data["updated"]),
          host_id:        data.dig("OS-EXT-SRV-ATTR:host"),
          tenant_id:      data["tenant_id"],
          addresses:      data["addresses"] || {},
          security_groups: (data["security_groups"] || []).map { |sg| sg["name"] },
          metadata:       metadata,
          contract_end_at: extract_contract_end_at(data, metadata),
          account_name:   account_name,
          region:         region,
          vps_version:    vps_version
        )
      end

      def self.from_db(row)
        new(
          id:               row["id"],
          name:             row["name"],
          status:           row["status"],
          vcpus:            row["vcpus"],
          ram:              row["ram"],
          flavor_id:        row["flavor_id"],
          created_at:       parse_time(row["created_at"]),
          updated_at:       parse_time(row["updated_at"]),
          host_id:          row["host_id"],
          tenant_id:        row["tenant_id"],
          addresses:        parse_json(row["addresses_json"]) || {},
          security_groups:  parse_json(row["security_groups_json"]) || [],
          metadata:         parse_json(row["metadata_json"]) || {},
          contract_end_at:  parse_time(row["contract_end_at"]),
          discount_ticket:  row["discount_ticket"],
          account_name:     row["account_name"],
          region:           row["region"],
          vps_version:      row["vps_version"]
        )
      end

      # 稼働中かどうか
      def running?
        @status == POWER_STATUS_ON
      end

      # 停止中かどうか
      def stopped?
        @status == POWER_STATUS_OFF
      end

      # RAM を人間が読みやすい形式に変換 (MB → GB)
      def ram_display
        return "-" unless @ram

        if @ram >= 1024
          "#{@ram / 1024}GB"
        else
          "#{@ram}MB"
        end
      end

      # グローバルIPアドレス一覧を返す
      def global_ips
        @addresses.values.flatten
                  .select { |a| a["OS-EXT-IPS:type"] == "floating" }
                  .map { |a| a["addr"] }
      end

      # 内部ネットワークIPアドレス一覧を返す
      def private_ips
        @addresses.values.flatten
                  .select { |a| a["OS-EXT-IPS:type"] == "fixed" }
                  .map { |a| a["addr"] }
      end

      # 割引切符の有無
      def discount_ticket?
        !@discount_ticket.nil? && !@discount_ticket.empty?
      end

      def to_db_hash
        {
          id:                   @id,
          name:                 @name,
          status:               @status,
          vcpus:                @vcpus,
          ram:                  @ram,
          flavor_id:            @flavor_id,
          created_at:           @created_at&.iso8601,
          updated_at:           @updated_at&.iso8601,
          host_id:              @host_id,
          tenant_id:            @tenant_id,
          addresses_json:       @addresses.to_json,
          security_groups_json: @security_groups.to_json,
          metadata_json:        @metadata.to_json,
          contract_end_at:      @contract_end_at&.iso8601,
          discount_ticket:      @discount_ticket,
          account_name:         @account_name,
          region:               @region,
          vps_version:          @vps_version
        }
      end

      private_class_method def self.extract_vcpus(data)
        data.dig("flavor", "vcpus") || data["vcpus"]
      end

      private_class_method def self.extract_ram(data)
        data.dig("flavor", "ram") || data["ram"]
      end

      private_class_method def self.extract_name(data, metadata)
        metadata["instance_name_tag"] ||
          metadata["name_tag"] ||
          metadata["nametag"] ||
          data["display_name"] ||
          data["name"]
      end

      private_class_method def self.extract_contract_end_at(data, metadata)
        keys = %w[contract_end_at contract_end end_at end_date expire_at expires_at expiration_date]

        keys.each do |key|
          time = parse_time(data[key] || metadata[key])
          return time if time
        end

        nil
      end

      private_class_method def self.parse_time(str)
        return nil unless str

        Time.parse(str).utc
      rescue ArgumentError, TypeError
        nil
      end

      private_class_method def self.parse_json(str)
        return nil unless str

        JSON.parse(str)
      rescue JSON::ParserError
        nil
      end
    end
  end
end
