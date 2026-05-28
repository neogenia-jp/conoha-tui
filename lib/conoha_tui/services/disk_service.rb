# frozen_string_literal: true

module ConohaTui
  module Services
    # ディスク（ボリューム）操作のビジネスロジックを担うサービスクラス。
    class DiskService
      def initialize(settings)
        @settings  = settings
        @disk_repo = Db::Repositories::DiskRepository.new
      end

      def list
        @disk_repo.all
      end

      def find(id)
        @disk_repo.find(id)
      end

      def refresh_all
        @settings.accounts.each do |account|
          refresh_account(account)
          yield account.name if block_given?
        end
      end

      def refresh_account(account)
        auth      = build_auth(account)
        vol_cl    = Api::VolumeClient.new(auth)
        volumes   = vol_cl.list_volumes

        disks = volumes.map do |data|
          Models::Disk.from_api(data, account_name: account.name, region: account.region)
        end

        @disk_repo.delete_by_account(account.name, account.region)
        @disk_repo.upsert_all(disks)
        disks
      end

      private

      def build_auth(account)
        auth = Api::AuthV2.new(account)
        auth.authenticate!
      end
    end
  end
end
