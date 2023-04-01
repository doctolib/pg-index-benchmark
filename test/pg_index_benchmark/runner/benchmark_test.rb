# frozen_string_literal: true

require_relative "../../test_helper.rb"
class PgIndexBenchmark::Runner::BenchmarkTest < Minitest::Test
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
        .with("reference", "000001", "Shared Read Blocks")
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
end
