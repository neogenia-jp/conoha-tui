# frozen_string_literal: true

module ConohaTui
  module Api
    # Swift Object Storage API クライアント。
    # オブジェクトストレージのコンテナ・オブジェクト一覧取得を行う。
    class ObjectStorageClient < BaseClient
      def initialize(auth)
        @auth = auth
        @conn = build_connection(object_storage_endpoint)
      end

      # コンテナ一覧を取得する
      def list_containers
        response = @conn.get("") do |req|
          req.headers["X-Auth-Token"] = @auth.token
          req.headers["Accept"]       = "application/json"
          req.params["format"]        = "json"
        end
        handle_response(response) || []
      end

      # コンテナ内のオブジェクト一覧を取得する
      # @param container [String] コンテナ名
      def list_objects(container)
        response = @conn.get("/#{URI.encode_www_form_component(container)}") do |req|
          req.headers["X-Auth-Token"] = @auth.token
          req.headers["Accept"]       = "application/json"
          req.params["format"]        = "json"
        end
        handle_response(response) || []
      end

      # アカウントメタデータを取得する
      def get_account_metadata
        response = @conn.head("") do |req|
          req.headers["X-Auth-Token"] = @auth.token
        end
        response.headers
      end

      private

      def object_storage_endpoint
        base = @auth.endpoints["object-store"] || @auth.endpoints["swift"]
        raise ApiError, "Object Storage エンドポイントが見つかりません" unless base

        base
      end
    end
  end
end
