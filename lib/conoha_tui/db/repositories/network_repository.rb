# frozen_string_literal: true

module ConohaTui
  module Db
    module Repositories
      # ネットワークデータの永続化・取得を行うリポジトリ。
      class NetworkRepository < BaseRepository
        def all(account_name: nil)
          if account_name
            rows = @db.execute(
              "SELECT * FROM networks WHERE account_name = ? ORDER BY name",
              [account_name]
            )
          else
            rows = @db.execute("SELECT * FROM networks ORDER BY account_name, name")
          end
          rows.map { |row| Models::Network.from_db(row) }
        end

        def find(id)
          row = @db.execute("SELECT * FROM networks WHERE id = ?", [id]).first
          row ? Models::Network.from_db(row) : nil
        end

        def upsert(network)
          h = network.to_db_hash
          h[:fetched_at] = now_iso8601

          values = h.values_at(
            :id, :name, :status, :shared, :admin_state_up,
            :provider_network_type, :subnets_json, :connected_server_ids_json,
            :account_name, :region, :fetched_at
          )
          @db.execute(<<~SQL, values)
            INSERT INTO networks (
              id, name, status, shared, admin_state_up,
              provider_network_type, subnets_json, connected_server_ids_json,
              account_name, region, fetched_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              name                      = excluded.name,
              status                    = excluded.status,
              shared                    = excluded.shared,
              admin_state_up            = excluded.admin_state_up,
              provider_network_type     = excluded.provider_network_type,
              subnets_json              = excluded.subnets_json,
              connected_server_ids_json = excluded.connected_server_ids_json,
              fetched_at                = excluded.fetched_at
          SQL
        end

        def upsert_all(networks)
          Database.transaction do
            networks.each { |n| upsert(n) }
          end
        end

        def delete_by_account(account_name, region)
          @db.execute(
            "DELETE FROM networks WHERE account_name = ? AND region = ?",
            [account_name, region]
          )
        end
      end
    end
  end
end
