# frozen_string_literal: true

require_relative "../../test_helper.rb"
class PgIndexBenchmark::CLI::OptionParserTest < Minitest::Test
  describe "benchmark mode" do
    def test_default
      assert_equal [{ mode: :benchmark }, []],
                   ::PgIndexBenchmark::CLI::OptionParser.new.parse([])
    end

    def test_with_query
      assert_equal [{ mode: :benchmark, only_query_fingerprint: "123456" }, []],
                   ::PgIndexBenchmark::CLI::OptionParser.new.parse(
                     %w[-q 123456]
                   )
    end

    def test_with_query_file
      assert_equal [{ mode: :benchmark }, ["queries.sql"]],
                   ::PgIndexBenchmark::CLI::OptionParser.new.parse(
                     ["queries.sql"]
                   )
    end

    def test_with_config_file
      assert_equal [
                     { mode: :benchmark, config_path: "foo_config.yml" },
                     ["queries.sql"]
                   ],
                   ::PgIndexBenchmark::CLI::OptionParser.new.parse(
                     %w[-c foo_config.yml queries.sql]
                   )
    end
  end

  describe "deduplicate mode" do
    def test_runs_in_benchmark_mode
      assert_equal [{ mode: :deduplicate, table_name: "foo" }, []],
                   ::PgIndexBenchmark::CLI::OptionParser.new.parse(%w[-d foo])
    end
  end
end
