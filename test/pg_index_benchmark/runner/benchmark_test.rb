# frozen_string_literal: true

require_relative "../../test_helper.rb"
class PgIndexBenchmark::Runner::BenchmarkTest < Minitest::Test
  EXECUTION_PLAN = <<-PLAN
[
  {
    Plan: {
      "Node Type": "Index Scan",
      "Parallel Aware": false,
      "Async Capable": false,
      "Scan Direction": "Forward",
      "Index Name": "books_pkey",
      "Relation Name": "books",
      Schema: "public",
      Alias: "books",
      "Startup Cost": 0.43,
      "Total Cost": 8.45,
      "Plan Rows": 1,
      "Plan Width": 25,
      "Actual Startup Time": 0.036,
      "Actual Total Time": 0.036,
      "Actual Rows": 1,
      "Actual Loops": 1,
      Output: %w[id title price available],
      "Index Cond": "(books.id = 123)",
      "Rows Removed by Index Recheck": 0,
      "Shared Hit Blocks": 4,
      "Shared Read Blocks": 0,
      "Shared Dirtied Blocks": 0,
      "Shared Written Blocks": 0,
      "Local Hit Blocks": 0,
      "Local Read Blocks": 0,
      "Local Dirtied Blocks": 0,
      "Local Written Blocks": 0,
      "Temp Read Blocks": 0,
      "Temp Written Blocks": 0
    },
    Planning: {
      "Shared Hit Blocks": 0,
      "Shared Read Blocks": 0,
      "Shared Dirtied Blocks": 0,
      "Shared Written Blocks": 0,
      "Local Hit Blocks": 0,
      "Local Read Blocks": 0,
      "Local Dirtied Blocks": 0,
      "Local Written Blocks": 0,
      "Temp Read Blocks": 0,
      "Temp Written Blocks": 0
    },
    "Planning Time": 0.056,
    Triggers: [],
    "Execution Time": 0.053
  }
]
PLAN
  class FakeConnectionResult
    def initialize(result)
      @result = result
    end
    def values
      @result
    end
  end
  class FakeConnection
    def initialize
      @expectations = {}
    end
    def expect(query, result = nil)
      @expectations[query] = [] unless @expectations.has_key?(query)
      @expectations[query] << result
      self
    end
    def exec(query)
      if @expectations.has_key?(query) && !@expectations[query].empty?
        return FakeConnectionResult.new(@expectations[query].shift)
      end
      raise "Unexpected query #{query}"
    end
    def remaining_expectations
      @expectations.select { |key, value| value.size > 0 }.keys
    end
  end

  describe "compare_plan_results" do
    before do
      PgIndexBenchmark::Runner::Benchmark.any_instance.stubs(
        :init_benchmark_results
      )
      PgIndexBenchmark::Runner::Benchmark.any_instance.stubs(
        :load_config_values
      )
      PgIndexBenchmark::Runner::Benchmark.any_instance.stubs(:load_options)
      @benchmark = PgIndexBenchmark::Runner::Benchmark.new({}, "")
    end

    it "prints one row when all plans have the same field value" do
      @benchmark.stubs(:plan_value).returns(0.0)

      assert_output("\nShared Read Blocks: 0.0 (same for all scenarios)\n") do
        @benchmark.send(
          :compare_plan_results,
          *[%i[scenario1 scenario2], "000001", "Shared Read Blocks"]
        )
      end
    end

    it "prints one row per scenario when they have different field values" do
      @benchmark.stubs(:scenario_names).returns(%w[scenario1 scenario2])
      @benchmark
        .stubs(:plan_value)
        .with(:reference, "000001", "Shared Read Blocks")
        .returns(12.0)

      @benchmark
        .stubs(:plan_value)
        .with(:scenario1, "000001", "Shared Read Blocks")
        .returns(12.0)

      @benchmark
        .stubs(:plan_value)
        .with(:scenario2, "000001", "Shared Read Blocks")
        .returns(25.0)

      expected_output = <<~MSG

        Shared Read Blocks:
          reference  12.0
          scenario1  12.0 ✅
          scenario2  25.0 ❌️
MSG
      assert_output(expected_output) do
        @benchmark.send(
          :compare_plan_results,
          *[%i[scenario1 scenario2], "000001", "Shared Read Blocks"]
        )
      end
    end
  end

  describe "runs" do
    it "drops the indexes for each scenarios" do
      existing_indexes =
        %w[
          books_pkey
          books_price_idx
          books_available_title_idx
          books_available_idx
          books_price_available_partial
          books_price_available_idx
        ].map { |index| [index] }
      fake_connection =
        FakeConnection
          .new
          .expect("BEGIN;")
          .expect(
            "select indexname from pg_indexes where tablename = 'books';",
            existing_indexes
          )
          .expect('DROP INDEX IF EXISTS "books_available_idx";')
          .expect('DROP INDEX IF EXISTS "books_price_available_partial";')
          .expect('DROP INDEX IF EXISTS "books_price_available_idx";')
          .expect("ROLLBACK;")
          .expect("BEGIN;")
          .expect(
            "select indexname from pg_indexes where tablename = 'books';",
            existing_indexes
          )
          .expect('DROP INDEX IF EXISTS "books_price_idx";')
          .expect('DROP INDEX IF EXISTS "books_available_title_idx";')
          .expect('DROP INDEX IF EXISTS "books_available_idx";')
          .expect('DROP INDEX IF EXISTS "books_price_available_idx";')
          .expect("ROLLBACK;")
          .expect("BEGIN;")
          .expect(
            "select indexname from pg_indexes where tablename = 'books';",
            existing_indexes
          )
          .expect('DROP INDEX IF EXISTS "books_price_idx";')
          .expect('DROP INDEX IF EXISTS "books_available_title_idx";')
          .expect('DROP INDEX IF EXISTS "books_available_idx";')
          .expect('DROP INDEX IF EXISTS "books_price_available_partial";')
          .expect("ROLLBACK;")
      PgIndexBenchmark::Runner::Benchmark
        .any_instance
        .stubs(:json_plan)
        .returns(EXECUTION_PLAN)

      PgIndexBenchmark::Runner::Benchmark
        .any_instance
        .stubs(:connection)
        .returns(fake_connection)

      PgIndexBenchmark::Runner::Benchmark
        .new(
          { config_path: "test/pg_index_benchmark/fixtures/config.yml" },
          "test/pg_index_benchmark/fixtures/duplicate_queries.sql"
        )
        .validate_config
        .run

      missing_calls = fake_connection.remaining_expectations
      assert_empty missing_calls,
                   "Some query calls where expected but never occured: #{missing_calls}"
    end
  end
end
