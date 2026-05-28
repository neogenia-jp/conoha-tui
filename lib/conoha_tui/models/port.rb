# frozen_string_literal: true

module ConohaTui
  module Models
    # ネットワークポート（セキュリティグループルール）を表すモデル。
    # ポートの開放・クローズ状況の管理に使用する。
    class Port
      attr_accessor :id, :rule_id, :sg_id, :sg_name, :server_id,
                    :protocol, :port_min, :port_max, :direction,
                    :remote_ip_prefix, :ethertype,
                    :account_name, :region

      def initialize(attrs = {})
        attrs.each { |k, v| public_send(:"#{k}=", v) if respond_to?(:"#{k}=") }
      end

      def self.from_api_rule(rule, sg_id:, sg_name:, account_name:, region:)
        new(
          rule_id:          rule["id"],
          sg_id:            sg_id,
          sg_name:          sg_name,
          protocol:         rule["protocol"],
          port_min:         rule["port_range_min"],
          port_max:         rule["port_range_max"],
          direction:        rule["direction"],
          remote_ip_prefix: rule["remote_ip_prefix"],
          ethertype:        rule["ethertype"],
          account_name:     account_name,
          region:           region
        )
      end

      def self.from_db(row)
        new(
          id:               row["id"],
          rule_id:          row["rule_id"],
          sg_id:            row["sg_id"],
          sg_name:          row["sg_name"],
          server_id:        row["server_id"],
          protocol:         row["protocol"],
          port_min:         row["port_min"],
          port_max:         row["port_max"],
          direction:        row["direction"],
          remote_ip_prefix: row["remote_ip_prefix"],
          ethertype:        row["ethertype"],
          account_name:     row["account_name"],
          region:           row["region"]
        )
      end

      # ポート表示文字列 (例: "TCP 80-80", "TCP 443-443")
      def port_display
        return "-" unless @protocol

        proto = @protocol.upcase
        if @port_min && @port_max
          @port_min == @port_max ? "#{proto} #{@port_min}" : "#{proto} #{@port_min}-#{@port_max}"
        else
          proto
        end
      end

      def to_db_hash
        {
          rule_id:          @rule_id,
          sg_id:            @sg_id,
          sg_name:          @sg_name,
          server_id:        @server_id,
          protocol:         @protocol,
          port_min:         @port_min,
          port_max:         @port_max,
          direction:        @direction,
          remote_ip_prefix: @remote_ip_prefix,
          ethertype:        @ethertype,
          account_name:     @account_name,
          region:           @region
        }
      end
    end
  end
end
