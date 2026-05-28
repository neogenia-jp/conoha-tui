# frozen_string_literal: true

module ConohaTui
  module Db
    # データベーススキーマの作成・マイグレーションを管理するクラス。
    class Schema
      def initialize(conn)
        @conn = conn
      end

      # スキーマを作成または更新する
      def migrate!
        create_vpses_table
        create_ports_table
        create_networks_table
        create_disks_table
        create_object_storage_containers_table
      end

      private

      def create_vpses_table
        @conn.execute(<<~SQL)
          CREATE TABLE IF NOT EXISTS vpses (
            id                   TEXT    PRIMARY KEY,
            name                 TEXT    NOT NULL,
            status               TEXT,
            vcpus                INTEGER,
            ram                  INTEGER,
            flavor_id            TEXT,
            created_at           TEXT,
            updated_at           TEXT,
            host_id              TEXT,
            tenant_id            TEXT,
            addresses_json       TEXT,
            security_groups_json TEXT,
            metadata_json        TEXT,
            contract_end_at      TEXT,
            discount_ticket      TEXT,
            account_name         TEXT    NOT NULL,
            region               TEXT    NOT NULL,
            vps_version          INTEGER NOT NULL DEFAULT 2,
            fetched_at           TEXT    NOT NULL DEFAULT (datetime('now'))
          )
        SQL
      end

      def create_ports_table
        @conn.execute(<<~SQL)
          CREATE TABLE IF NOT EXISTS ports (
            id               INTEGER PRIMARY KEY AUTOINCREMENT,
            rule_id          TEXT    UNIQUE,
            sg_id            TEXT    NOT NULL,
            sg_name          TEXT,
            server_id        TEXT,
            protocol         TEXT,
            port_min         INTEGER,
            port_max         INTEGER,
            direction        TEXT,
            remote_ip_prefix TEXT,
            ethertype        TEXT,
            account_name     TEXT    NOT NULL,
            region           TEXT    NOT NULL,
            fetched_at       TEXT    NOT NULL DEFAULT (datetime('now'))
          )
        SQL
      end

      def create_networks_table
        @conn.execute(<<~SQL)
          CREATE TABLE IF NOT EXISTS networks (
            id                        TEXT PRIMARY KEY,
            name                      TEXT,
            status                    TEXT,
            shared                    INTEGER DEFAULT 0,
            admin_state_up            INTEGER DEFAULT 1,
            provider_network_type     TEXT,
            subnets_json              TEXT,
            connected_server_ids_json TEXT,
            account_name              TEXT NOT NULL,
            region                    TEXT NOT NULL,
            fetched_at                TEXT NOT NULL DEFAULT (datetime('now'))
          )
        SQL
      end

      def create_disks_table
        @conn.execute(<<~SQL)
          CREATE TABLE IF NOT EXISTS disks (
            id               TEXT PRIMARY KEY,
            name             TEXT,
            status           TEXT,
            size             INTEGER,
            volume_type      TEXT,
            created_at       TEXT,
            attachments_json TEXT,
            account_name     TEXT NOT NULL,
            region           TEXT NOT NULL,
            fetched_at       TEXT NOT NULL DEFAULT (datetime('now'))
          )
        SQL
      end

      def create_object_storage_containers_table
        @conn.execute(<<~SQL)
          CREATE TABLE IF NOT EXISTS object_storage_containers (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            name         TEXT    NOT NULL,
            object_count INTEGER DEFAULT 0,
            bytes_used   INTEGER DEFAULT 0,
            account_name TEXT    NOT NULL,
            region       TEXT    NOT NULL,
            fetched_at   TEXT    NOT NULL DEFAULT (datetime('now')),
            UNIQUE (name, account_name, region)
          )
        SQL
      end
    end
  end
end
