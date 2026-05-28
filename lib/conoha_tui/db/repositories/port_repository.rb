# frozen_string_literal: true

module ConohaTui
  module Db
    module Repositories
      # ポート（セキュリティグループルール）データの永続化・取得を行うリポジトリ。
      class PortRepository < BaseRepository
        # 指定サーバーIDに紐づくポート一覧を取得する
        def by_server(server_id)
          rows = @db.execute(
            "SELECT * FROM ports WHERE server_id = ? ORDER BY protocol, port_min",
            [server_id]
          )
          rows.map { |row| Models::Port.from_db(row) }
        end

        # セキュリティグループIDに紐づくポート一覧を取得する
        def by_security_group(sg_id)
          rows = @db.execute(
            "SELECT * FROM ports WHERE sg_id = ? ORDER BY protocol, port_min",
            [sg_id]
          )
          rows.map { |row| Models::Port.from_db(row) }
        end

        # ポートを upsert する
        def upsert(port)
          h = port.to_db_hash
          h[:fetched_at] = now_iso8601

          values = h.values_at(
            :rule_id, :sg_id, :sg_name, :server_id,
            :protocol, :port_min, :port_max, :direction,
            :remote_ip_prefix, :ethertype,
            :account_name, :region, :fetched_at
          )
          @db.execute(<<~SQL, values)
            INSERT INTO ports (
              rule_id, sg_id, sg_name, server_id,
              protocol, port_min, port_max, direction,
              remote_ip_prefix, ethertype,
              account_name, region, fetched_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(rule_id) DO UPDATE SET
              sg_name          = excluded.sg_name,
              server_id        = excluded.server_id,
              fetched_at       = excluded.fetched_at
          SQL
        end

        def upsert_all(ports)
          Database.transaction do
            ports.each { |p| upsert(p) }
          end
        end

        def delete_by_security_group(sg_id)
          @db.execute("DELETE FROM ports WHERE sg_id = ?", [sg_id])
        end

        def delete_by_account(account_name, region)
          @db.execute(
            "DELETE FROM ports WHERE account_name = ? AND region = ?",
            [account_name, region]
          )
        end
      end
    end
  end
end
