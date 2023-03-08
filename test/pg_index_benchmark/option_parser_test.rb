# frozen_string_literal: true

require_relative "../../lib/pg_index_benchmark/option_parser"
require "minitest/autorun"
class OptionParserTest < Minitest::Test
  describe "benchmark mode" do
    def test_default
      assert_equal [{ mode: :benchmark }, []],
                   ::PgIndexBenchmark::OptionParser.new.parse([])
    end

    def test_with_query
      assert_equal [{ mode: :benchmark, only_query_fingerprint: "123456" }, []],
                   ::PgIndexBenchmark::OptionParser.new.parse(%w[-q 123456])
    end

    def test_with_query_file
      assert_equal [{ mode: :benchmark }, ["queries.sql"]],
                   ::PgIndexBenchmark::OptionParser.new.parse(["queries.sql"])
    end

    def test_with_config_file
      assert_equal [{ mode: :benchmark, config_path: "foo_config.yml" }, []],
                   ::PgIndexBenchmark::OptionParser.new.parse(
                     %w[-c foo_config.yml]
                   )
    end
  end

  describe "deduplicate mode" do
    def test_runs_in_benchmark_mode
      assert_equal [{ mode: :deduplicate }, []],
                   ::PgIndexBenchmark::OptionParser.new.parse(["-d"])
    end
  end
end
