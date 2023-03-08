# frozen_string_literal: true
module PgIndexBenchmark
  module Runner
    class Benchmark
      def initialize(options, query_file_path)
        init_benchmark_results
        load_options(options, query_file_path)
        load_config_values
      end

      def validate_config
        @config.validate
        self
      end

      def run
        benchmark_tool = IndexBenchmarkTool.new(@config)
        benchmark_tool.run_benchmark
      end

      private

      def init_benchmark_results
        @result_plans = {}
        @queries_by_fingerprint = {}
        @queries_run_in_scenario = 0
        @not_impacted_queries = []
      end

      def load_config_values
        %i[
          db_host
          db_port
          db_name
          db_user
          db_password
          scenarios
          table_name
          common_indexes
          query_prerun_count
          only_query_fingerprint
          input_file_path
          max_queries_per_scenario
        ].each do |field|
          instance_variable_set("@#{field}", @config.send(field))
        end
      end

      def load_options(options, query_file_path)
        @config =
          PgIndexBenchmark::ConfigLoader.new(
            options[:config_path] || "config.yml"
          )
        @config.input_file_path = query_file_path
        @config.query_prerun_count = options[:times]&.to_i || 0
        @config.max_queries_per_scenario =
          options[:max_queries_per_scenario]&.to_i || 500
        @config.only_query_fingerprint =
          options[:only_query_fingerprint] if options[:only_query_fingerprint]
      end
    end
  end
end
