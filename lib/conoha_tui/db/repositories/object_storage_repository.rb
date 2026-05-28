# frozen_string_literal: true

module ConohaTui
  module Db
    module Repositories
      # オブジェクトストレージコンテナデータの永続化・取得を行うリポジトリ。
      class ObjectStorageRepository < BaseRepository
        def all(account_name: nil)
          if account_name
            rows = @db.execute(
              "SELECT * FROM object_storage_containers WHERE account_name = ? ORDER BY name",
              [account_name]
            )
          else
            rows = @db.execute(
              "SELECT * FROM object_storage_containers ORDER BY account_name, name"
            )
          end
          rows.map { |row| Models::ObjectStorageContainer.from_db(row) }
        end

        def upsert(container)
          h = container.to_db_hash
          h[:fetched_at] = now_iso8601

          values = h.values_at(
            :name, :object_count, :bytes_used,
            :account_name, :region, :fetched_at
          )
          @db.execute(<<~SQL, values)
            INSERT INTO object_storage_containers (
              name, object_count, bytes_used,
              account_name, region, fetched_at
            ) VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(name, account_name, region) DO UPDATE SET
              object_count = excluded.object_count,
              bytes_used   = excluded.bytes_used,
              fetched_at   = excluded.fetched_at
          SQL
        end

        def upsert_all(containers)
          Database.transaction do
            containers.each { |c| upsert(c) }
          end
        end

        def delete_by_account(account_name, region)
          @db.execute(
            "DELETE FROM object_storage_containers WHERE account_name = ? AND region = ?",
            [account_name, region]
          )
        end
      end
    end
  end
end
