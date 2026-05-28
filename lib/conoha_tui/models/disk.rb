# frozen_string_literal: true

module ConohaTui
  module Models
    # 追加ディスク（Cinder ボリューム）を表すモデル。
    class Disk
      attr_accessor :id, :name, :status, :size, :volume_type,
                    :created_at, :attachments,
                    :account_name, :region

      def initialize(attrs = {})
        attrs.each { |k, v| public_send(:"#{k}=", v) if respond_to?(:"#{k}=") }
        @attachments ||= []
      end

      def self.from_api(data, account_name:, region:)
        new(
          id:          data["id"],
          name:        data["name"] || data["display_name"],
          status:      data["status"],
          size:        data["size"],
          volume_type: data["volume_type"],
          created_at:  parse_time(data["created_at"]),
          attachments: data["attachments"] || [],
          account_name: account_name,
          region:       region
        )
      end

      def self.from_db(row)
        new(
          id:           row["id"],
          name:         row["name"],
          status:       row["status"],
          size:         row["size"],
          volume_type:  row["volume_type"],
          created_at:   parse_time(row["created_at"]),
          attachments:  parse_json(row["attachments_json"]) || [],
          account_name: row["account_name"],
          region:       row["region"]
        )
      end

      # 接続中サーバーIDの一覧
      def attached_server_ids
        @attachments.map { |a| a["server_id"] }.compact
      end

      # 接続中かどうか
      def attached?
        @attachments.any?
      end

      # サイズ表示 (GB)
      def size_display
        @size ? "#{@size}GB" : "-"
      end

      def to_db_hash
        {
          id:               @id,
          name:             @name,
          status:           @status,
          size:             @size,
          volume_type:      @volume_type,
          created_at:       @created_at&.iso8601,
          attachments_json: @attachments.to_json,
          account_name:     @account_name,
          region:           @region
        }
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
