# frozen_string_literal: true

require_relative "../test_helper"

module ConohaTui
  module Models
    class TestNetwork < Minitest::Test
      def test_from_api
        data = {
          "id"                    => "net-001",
          "name"                  => "テストネットワーク",
          "status"                => "ACTIVE",
          "shared"                => false,
          "admin_state_up"        => true,
          "provider:network_type" => "local",
          "subnets"               => ["subnet-001"]
        }

        net = Network.from_api(data, account_name: "account1", region: "tyo1")
        assert_equal "net-001", net.id
        assert_equal "テストネットワーク", net.name
        assert_equal ["subnet-001"], net.subnets
        assert_equal "account1", net.account_name
      end

      def test_from_db
        row = {
          "id"                        => "net-002",
          "name"                      => "db-network",
          "status"                    => "ACTIVE",
          "shared"                    => 0,
          "admin_state_up"            => 1,
          "provider_network_type"     => "vlan",
          "subnets_json"              => '["sub-001","sub-002"]',
          "connected_server_ids_json" => '["srv-001"]',
          "account_name"              => "account2",
          "region"                    => "tyo2"
        }

        net = Network.from_db(row)
        assert_equal "net-002", net.id
        assert_equal ["sub-001", "sub-002"], net.subnets
        assert_equal ["srv-001"], net.connected_server_ids
        refute net.shared
      end

      def test_to_db_hash
        net = Network.from_api(
          { "id" => "n1", "name" => "net1", "status" => "ACTIVE",
            "shared" => true, "admin_state_up" => true,
            "provider:network_type" => nil, "subnets" => [] },
          account_name: "acc", region: "tyo3"
        )
        h = net.to_db_hash
        assert_equal 1, h[:shared]
        assert_equal "acc", h[:account_name]
        assert_equal "[]", h[:subnets_json]
      end
    end
  end
end
