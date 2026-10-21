# frozen_string_literal: true

module ConohaTui
  module Services
    # 全アカウントの再取得処理を共通化する。
    # 認証エラーなどでアカウントが失敗しても、残りのアカウントの取得を継続する。
    module AccountRefresh
      private

      # @yield [Config::Account] アカウントごとの取得処理
      # @return [Array<Array(String, String)>] 失敗したアカウントの [アカウント名, エラーメッセージ]
      def each_account_collecting_errors
        errors = []
        @settings.accounts.each do |account|
          yield account
        rescue Api::BaseClient::ApiError, Faraday::Error => e
          errors << [account.name, e.message]
        end
        errors
      end
    end
  end
end
