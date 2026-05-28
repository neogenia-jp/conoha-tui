# frozen_string_literal: true

module ConohaTui
  module Models
    # オブジェクトストレージのコンテナを表すモデル。
    class ObjectStorageContainer
      attr_accessor :name, :count, :bytes, :account_name, :region

      def initialize(attrs = {})
        attrs.each { |k, v| public_send(:"#{k}=", v) if respond_to?(:"#{k}=") }
      end

      def self.from_api(data, account_name:, region:)
        new(
          name:         data["name"],
          count:        data["count"],
          bytes:        data["bytes"],
          account_name: account_name,
          region:       region
        )
      end

      def self.from_db(row)
        new(
          name:         row["name"],
          count:        row["object_count"],
          bytes:        row["bytes_used"],
          account_name: row["account_name"],
          region:       row["region"]
        )
      end

      # バイトを人間が読みやすい形式に変換
      def bytes_display
        return "-" unless @bytes

        if @bytes >= 1_073_741_824
          format("%.1fGB", @bytes.to_f / 1_073_741_824)
        elsif @bytes >= 1_048_576
          format("%.1fMB", @bytes.to_f / 1_048_576)
        elsif @bytes >= 1_024
          format("%.1fKB", @bytes.to_f / 1_024)
        else
          "#{@bytes}B"
        end
      end

      def to_db_hash
        {
          name:         @name,
          object_count: @count,
          bytes_used:   @bytes,
          account_name: @account_name,
          region:       @region
        }
      end
    end
  end
end
