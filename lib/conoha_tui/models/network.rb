# frozen_string_literal: true

module ConohaTui
  module Models
    # 内部ネットワークを表すモデル。
    class Network
      attr_accessor :id, :name, :status, :shared, :admin_state_up,
                    :provider_network_type, :subnets,
                    :connected_server_ids,
                    :account_name, :region

      def initialize(attrs = {})
        attrs.each { |k, v| public_send(:"#{k}=", v) if respond_to?(:"#{k}=") }
        @connected_server_ids ||= []
        @subnets              ||= []
      end

      def self.from_api(data, account_name:, region:)
        new(
          id:                    data["id"],
          name:                  data["name"],
          status:                data["status"],
          shared:                data["shared"],
          admin_state_up:        data["admin_state_up"],
          provider_network_type: data["provider:network_type"],
          subnets:               data["subnets"] || [],
          account_name:          account_name,
          region:                region
        )
      end

      def self.from_db(row)
        new(
          id:                    row["id"],
          name:                  row["name"],
          status:                row["status"],
          shared:                row["shared"] == 1,
          admin_state_up:        row["admin_state_up"] == 1,
          provider_network_type: row["provider_network_type"],
          subnets:               parse_json(row["subnets_json"]) || [],
          connected_server_ids:  parse_json(row["connected_server_ids_json"]) || [],
          account_name:          row["account_name"],
          region:                row["region"]
        )
      end

      def to_db_hash
        {
          id:                       @id,
          name:                     @name,
          status:                   @status,
          shared:                   @shared ? 1 : 0,
          admin_state_up:           @admin_state_up ? 1 : 0,
          provider_network_type:    @provider_network_type,
          subnets_json:             @subnets.to_json,
          connected_server_ids_json: @connected_server_ids.to_json,
          account_name:             @account_name,
          region:                   @region
        }
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
