# frozen_string_literal: true

module ConohaTui
  module Db
    module Repositories
      # ディスク（ボリューム）データの永続化・取得を行うリポジトリ。
      class DiskRepository < BaseRepository
        def all(account_name: nil)
          if account_name
            rows = @db.execute(
              "SELECT * FROM disks WHERE account_name = ? ORDER BY name",
              [account_name]
            )
          else
            rows = @db.execute("SELECT * FROM disks ORDER BY account_name, name")
          end
          rows.map { |row| Models::Disk.from_db(row) }
        end

        def find(id)
          row = @db.execute("SELECT * FROM disks WHERE id = ?", [id]).first
          row ? Models::Disk.from_db(row) : nil
        end

        def upsert(disk)
          h = disk.to_db_hash
          h[:fetched_at] = now_iso8601

          values = h.values_at(
            :id, :name, :status, :size, :volume_type,
            :created_at, :attachments_json,
            :account_name, :region, :fetched_at
          )
          @db.execute(<<~SQL, values)
            INSERT INTO disks (
              id, name, status, size, volume_type,
              created_at, attachments_json,
              account_name, region, fetched_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              name             = excluded.name,
              status           = excluded.status,
              size             = excluded.size,
              attachments_json = excluded.attachments_json,
              fetched_at       = excluded.fetched_at
          SQL
        end

        def upsert_all(disks)
          Database.transaction do
            disks.each { |d| upsert(d) }
          end
        end

        def delete_by_account(account_name, region)
          @db.execute(
            "DELETE FROM disks WHERE account_name = ? AND region = ?",
            [account_name, region]
          )
        end
      end
    end
  end
end
