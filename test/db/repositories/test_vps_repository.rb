# frozen_string_literal: true

require_relative "../../test_helper"

module ConohaTui
  module Db
    module Repositories
      class TestVpsRepository < Minitest::Test
        def setup
          @repo = VpsRepository.new(test_db)
        end

        def test_upsert_and_find
          vps = sample_vps
          @repo.upsert(vps)

          found = @repo.find(vps.id)
          refute_nil found
          assert_equal vps.id,   found.id
          assert_equal vps.name, found.name
        end

        def test_all_returns_vpses
          @repo.upsert(sample_vps(id: "id-001", name: "server-a"))
          @repo.upsert(sample_vps(id: "id-002", name: "server-b"))

          vpses = @repo.all
          assert_equal 2, vpses.size
        end

        def test_all_filters_by_account_name
          @repo.upsert(sample_vps(id: "id-001", account_name: "account-A"))
          @repo.upsert(sample_vps(id: "id-002", account_name: "account-B"))

          result = @repo.all(account_name: "account-A")
          assert_equal 1, result.size
          assert_equal "account-A", result.first.account_name
        end

        def test_upsert_updates_existing
          vps = sample_vps
          @repo.upsert(vps)

          vps.status = "SHUTOFF"
          @repo.upsert(vps)

          found = @repo.find(vps.id)
          assert_equal "SHUTOFF", found.status
        end

        def test_delete_removes_vps
          vps = sample_vps
          @repo.upsert(vps)
          @repo.delete(vps.id)

          assert_nil @repo.find(vps.id)
        end

        def test_delete_by_account
          @repo.upsert(sample_vps(id: "id-001", account_name: "acc-A", region: "tyo1"))
          @repo.upsert(sample_vps(id: "id-002", account_name: "acc-B", region: "tyo1"))

          @repo.delete_by_account("acc-A", "tyo1")
          assert_empty @repo.all(account_name: "acc-A")
          assert_equal 1, @repo.all(account_name: "acc-B").size
        end

        def test_search_by_name
          @repo.upsert(sample_vps(id: "id-001", name: "web-server-01"))
          @repo.upsert(sample_vps(id: "id-002", name: "db-server-01"))

          result = @repo.search("web")
          assert_equal 1, result.size
          assert_equal "web-server-01", result.first.name
        end

        def test_search_returns_empty_when_no_match
          @repo.upsert(sample_vps(name: "web-server"))
          assert_empty @repo.search("nonexistent")
        end

        def test_upsert_all_in_transaction
          vpses = [
            sample_vps(id: "id-001", name: "server-1"),
            sample_vps(id: "id-002", name: "server-2"),
            sample_vps(id: "id-003", name: "server-3")
          ]
          @repo.upsert_all(vpses)
          assert_equal 3, @repo.all.size
        end

        private

        def sample_vps(overrides = {})
          Models::Vps.new({
            id:           "test-vps-id-001",
            name:         "test-server",
            status:       "ACTIVE",
            vcpus:        2,
            ram:          2048,
            flavor_id:    "g-2gb",
            created_at:   Time.now.utc,
            updated_at:   Time.now.utc,
            host_id:      "host001",
            tenant_id:    "tenant001",
            addresses:    {},
            security_groups: [],
            metadata:     {},
            account_name: "test-account",
            region:       "tyo1",
            vps_version:  2
          }.merge(overrides))
        end
      end
    end
  end
end
