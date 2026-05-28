# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"

module ConohaTui
  module Api
    # すべての API クライアントの基底クラス。
    # Faraday による HTTP 通信、エラーハンドリングを提供する。
    class BaseClient
      class ApiError < StandardError
        attr_reader :status, :body

        def initialize(message, status: nil, body: nil)
          super(message)
          @status = status
          @body   = body
        end
      end

      class AuthError        < ApiError; end
      class NotFoundError    < ApiError; end
      class RateLimitError   < ApiError; end
      class ServerError      < ApiError; end
      class NetworkError     < ApiError; end

      RETRY_OPTIONS = {
        max: 3,
        interval: 0.5,
        interval_randomness: 0.5,
        backoff_factor: 2,
        exceptions: [
          Faraday::ConnectionFailed,
          Faraday::TimeoutError
        ]
      }.freeze

      protected

      def build_connection(base_url)
        Faraday.new(url: base_url) do |f|
          f.request  :json
          f.response :json, content_type: /\bjson$/
          f.request  :retry, RETRY_OPTIONS
          f.adapter  Faraday.default_adapter
        end
      end

      def handle_response(response)
        case response.status
        when 200..299
          response.body
        when 401
          raise AuthError.new("認証エラー: トークンが無効または期限切れです",
                              status: response.status, body: response.body)
        when 404
          raise NotFoundError.new("リソースが見つかりません",
                                  status: response.status, body: response.body)
        when 429
          raise RateLimitError.new("レート制限に達しました。しばらく待ってから再試行してください",
                                   status: response.status, body: response.body)
        when 500..599
          raise ServerError.new("サーバーエラー (#{response.status})",
                                status: response.status, body: response.body)
        else
          raise ApiError.new("予期しないレスポンス (#{response.status})",
                             status: response.status, body: response.body)
        end
      end
    end
  end
end
