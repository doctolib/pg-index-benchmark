module PgIndexBenchmark
  module Runner
    class Benchmark
      def initialize(config, query_file_path)

      end

      def validate_config
      end

      def run

      end


      private
      def foo
        config = ConfigLoader.new(options[:config_path] || "config.yml")
        config.input_file_path = other_args[0]
        config.query_prerun_count = options[:times]&.to_i || 0
        config.max_queries_per_scenario =
          options[:max_queries_per_scenario]&.to_i || 500
        config.only_query_fingerprint =
          options[:only_query_fingerprint] if options[:only_query_fingerprint]

        config.check
        benchmark_tool = IndexBenchmarkTool.new(config)
        benchmark_tool.run_benchmark
      end
    end
  end
end