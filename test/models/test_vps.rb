# frozen_string_literal: true

require_relative "../test_helper"

module ConohaTui
  module Models
    class TestVps < Minitest::Test
      def test_from_api
        data = test_server_hash
        vps  = Vps.from_api(data, account_name: "my-account", region: "tyo1", vps_version: 2)

        assert_equal "aaaabbbb-cccc-dddd-eeee-ffffgggghhh1", vps.id
        assert_equal "test-server-01", vps.name
        assert_equal "ACTIVE", vps.status
        assert_equal 2, vps.vcpus
        assert_equal 2048, vps.ram
        assert_equal "my-account", vps.account_name
        assert_equal "tyo1", vps.region
        assert_equal 2, vps.vps_version
      end

      def test_running?
        vps = Vps.new(status: "ACTIVE")
        assert vps.running?
        refute vps.stopped?
      end

      def test_stopped?
        vps = Vps.new(status: "SHUTOFF")
        assert vps.stopped?
        refute vps.running?
      end

      def test_ram_display_gb
        vps = Vps.new(ram: 4096)
        assert_equal "4GB", vps.ram_display
      end

      def test_ram_display_mb
        vps = Vps.new(ram: 512)
        assert_equal "512MB", vps.ram_display
      end

      def test_ram_display_nil
        vps = Vps.new(ram: nil)
        assert_equal "-", vps.ram_display
      end

      def test_global_ips
        vps = Vps.from_api(test_server_hash, account_name: "a", region: "tyo1", vps_version: 2)
        assert_equal ["203.0.113.1"], vps.global_ips
      end

      def test_private_ips
        vps = Vps.from_api(test_server_hash, account_name: "a", region: "tyo1", vps_version: 2)
        assert_equal ["192.168.0.1"], vps.private_ips
      end

      def test_discount_ticket_present
        vps = Vps.new(discount_ticket: "ticket-001")
        assert vps.discount_ticket?
      end

      def test_discount_ticket_absent
        vps = Vps.new(discount_ticket: nil)
        refute vps.discount_ticket?
      end

      def test_to_db_hash_round_trip
        vps = Vps.from_api(test_server_hash, account_name: "a", region: "tyo1", vps_version: 2)
        hash = vps.to_db_hash

        assert_equal vps.id,       hash[:id]
        assert_equal vps.name,     hash[:name]
        assert_equal vps.vcpus,    hash[:vcpus]
        assert_equal "tyo1",       hash[:region]
        assert_equal 2,            hash[:vps_version]
      end

      def test_from_db
        db_row = {
          "id"                   => "test-id",
          "name"                 => "db-server",
          "status"               => "SHUTOFF",
          "vcpus"                => 4,
          "ram"                  => 8192,
          "flavor_id"            => "g-8gb",
          "created_at"           => "2024-01-01T00:00:00Z",
          "updated_at"           => nil,
          "host_id"              => "host_abc",
          "tenant_id"            => "tenant_001",
          "addresses_json"       => "{}",
          "security_groups_json" => '["default"]',
          "metadata_json"        => "{}",
          "contract_end_at"      => nil,
          "discount_ticket"      => nil,
          "account_name"         => "test",
          "region"               => "tyo2",
          "vps_version"          => 3
        }

        vps = Vps.from_db(db_row)
        assert_equal "test-id",  vps.id
        assert_equal "db-server", vps.name
        assert_equal 4,          vps.vcpus
        assert_equal "tyo2",     vps.region
        assert_equal 3,          vps.vps_version
      end
    end
  end
end
