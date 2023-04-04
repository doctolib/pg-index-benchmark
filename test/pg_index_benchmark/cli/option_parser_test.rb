# frozen_string_literal: true

require_relative "../../test_helper.rb"
class PgIndexBenchmark::CLI::OptionParserTest < Minitest::Test
  describe "benchmark mode" do
    it "returns no options when no args are provided" do
      assert_equal [{ mode: :benchmark }, []],
                   ::PgIndexBenchmark::CLI::OptionParser.new.parse([])
    end

    it "returns query when query is provided" do
      assert_equal [{ mode: :benchmark, only_query_fingerprint: "123456" }, []],
                   ::PgIndexBenchmark::CLI::OptionParser.new.parse(
                     %w[-q 123456]
                   )
    end

    it "returns query file when query file is provided" do
      assert_equal [{ mode: :benchmark }, ["queries.sql"]],
                   ::PgIndexBenchmark::CLI::OptionParser.new.parse(
                     ["queries.sql"]
                   )
    end

    it "retunrs config file and query file when both are provided" do
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
    it "detects deduplication mode" do
      assert_equal [{ mode: :deduplicate, table_name: "foo" }, []],
                   ::PgIndexBenchmark::CLI::OptionParser.new.parse(%w[-d foo])
    end
  end
end
