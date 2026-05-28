# frozen_string_literal: true

module ConohaTui
  module Db
    module Repositories
      # VPS データの永続化・取得を行うリポジトリ。
      class VpsRepository < BaseRepository
        # VPS をキャッシュから一覧取得する
        # @param account_name [String, nil] アカウント名フィルタ
        def all(account_name: nil)
          if account_name
            rows = @db.execute(
              "SELECT * FROM vpses WHERE account_name = ? ORDER BY name",
              [account_name]
            )
          else
            rows = @db.execute("SELECT * FROM vpses ORDER BY account_name, name")
          end
          rows.map { |row| Models::Vps.from_db(row) }
        end

        # ID で VPS を取得する
        def find(id)
          row = @db.execute("SELECT * FROM vpses WHERE id = ?", [id]).first
          row ? Models::Vps.from_db(row) : nil
        end

        # VPS を upsert する（存在すれば更新、なければ挿入）
        def upsert(vps)
          h = vps.to_db_hash
          h[:fetched_at] = now_iso8601

          values = h.values_at(
            :id, :name, :status, :vcpus, :ram, :flavor_id,
            :created_at, :updated_at, :host_id, :tenant_id,
            :addresses_json, :security_groups_json, :metadata_json,
            :contract_end_at, :discount_ticket,
            :account_name, :region, :vps_version, :fetched_at
          )
          @db.execute(<<~SQL, values)
            INSERT INTO vpses (
              id, name, status, vcpus, ram, flavor_id,
              created_at, updated_at, host_id, tenant_id,
              addresses_json, security_groups_json, metadata_json,
              contract_end_at, discount_ticket,
              account_name, region, vps_version, fetched_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              name                 = excluded.name,
              status               = excluded.status,
              vcpus                = excluded.vcpus,
              ram                  = excluded.ram,
              flavor_id            = excluded.flavor_id,
              updated_at           = excluded.updated_at,
              host_id              = excluded.host_id,
              addresses_json       = excluded.addresses_json,
              security_groups_json = excluded.security_groups_json,
              metadata_json        = excluded.metadata_json,
              contract_end_at      = excluded.contract_end_at,
              discount_ticket      = excluded.discount_ticket,
              fetched_at           = excluded.fetched_at
          SQL
        end

        # 複数の VPS を一括 upsert する
        def upsert_all(vpses)
          Database.transaction do
            vpses.each { |v| upsert(v) }
          end
        end

        # VPS を削除する
        def delete(id)
          @db.execute("DELETE FROM vpses WHERE id = ?", [id])
        end

        # アカウント・リージョンに属する VPS を全削除する（再取得前の掃除に使用）
        def delete_by_account(account_name, region)
          @db.execute(
            "DELETE FROM vpses WHERE account_name = ? AND region = ?",
            [account_name, region]
          )
        end

        # 名前または収容ホストで部分一致フィルタ
        def search(query)
          tokens = query.to_s.split(/[,、]/).map(&:strip).reject(&:empty?)
          return all if tokens.empty?

          clauses = tokens.map { "(name LIKE ? OR host_id LIKE ?)" }
          sql = "SELECT * FROM vpses WHERE #{clauses.join(' OR ')} ORDER BY name"
          params = tokens.flat_map do |token|
            pattern = "%#{token}%"
            [pattern, pattern]
          end

          rows = @db.execute(sql, params)
          rows.map { |row| Models::Vps.from_db(row) }
        end
      end
    end
  end
end
