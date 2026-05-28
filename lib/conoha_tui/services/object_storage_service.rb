# frozen_string_literal: true

module ConohaTui
  module Services
    # オブジェクトストレージ操作のビジネスロジックを担うサービスクラス。
    class ObjectStorageService
      def initialize(settings)
        @settings = settings
        @obj_repo = Db::Repositories::ObjectStorageRepository.new
      end

      def list
        @obj_repo.all
      end

      def refresh_all
        @settings.accounts.each do |account|
          refresh_account(account)
          yield account.name if block_given?
        end
      end

      def refresh_account(account)
        auth   = build_auth(account)
        obj_cl = Api::ObjectStorageClient.new(auth)
        data   = obj_cl.list_containers

        containers = data.map do |item|
          Models::ObjectStorageContainer.from_api(item,
                                                  account_name: account.name,
                                                  region:       account.region)
        end

        @obj_repo.delete_by_account(account.name, account.region)
        @obj_repo.upsert_all(containers)
        containers
      rescue Api::BaseClient::ApiError
        # オブジェクトストレージを使っていないアカウントはスキップ
        []
      end

      private

      def build_auth(account)
        auth = Api::AuthV2.new(account)
        auth.authenticate!
      end
    end
  end
end
