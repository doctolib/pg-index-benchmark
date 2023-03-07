# frozen_string_literal: true
require 'optparse'

module PgIndexBenchmark
  class OptionParser
    def parse(args)
      options = { mode: :benchmark }
      parser =
        ::OptionParser.new do |opts|
          add_banner(opts)

          # parser.on("-h", "--help", "Prints this help") do
          #   puts parser
          #   exit
          # end

          opts.on(
            "-d",
            "--deduplicate-only",
            "Only deduplicate queries from input file, and copy them when they are related to table_name"
          ) { options[:mode] = :deduplicate }

          opts.on(
            "-n times",
            "--load-cache-run times",
            "Run each query n times priori to get the plan, in order to have an up to date cache"
          ) { |times| options[:times] = times }

          opts.on(
            "-q query_fingerprint",
            "--only-query=query_fingerprint",
            "Benchmark only the query matching query_fingerprint"
          ) { |fingerprint| options[:only_query_fingerprint] = fingerprint }

          opts.on(
            "-c config_file.yml",
            "--config=config_file.yml",
            "Specify the config file instead of config_file.yml"
          ) { |config_path| options[:config_path] = config_path }

          opts.on(
            "-m n",
            "--max-queries-per-scenario=n",
            "Specify the max queries to run per scenario. If this amount is reached further queries will be ignored"
          ) { |n| options[:max_queries_per_scenario] = n }
        end
      options[:other_args] = parser.parse!(args)
    end

    def add_banner(opts)
      banner = [
        "Run queries and compare their plans with multiple index scenarios",
        "",
        "USAGE: #{File.basename($0)} [ --help ] [ -q query_fingerprint ] [input_file.sql]",
        "",
        "The input file should contain the list of queries to use for the benchmark. Multiline queries are allowed, but should be separated with a ;",
        " ",
        " ",
        "Connection config:",
        "By default, the localhost connection is used on local port.",
        "Override the environment variables to connect to other db:",
        "  POSTGRES_HOST, POSTGRES_PORT, POSTGRES_DATABASE, POSTGRES_USER, POSTGRES_PASSWORD"
      ].join(
        "
        "
      )
      opts.banner = Rainbow.wrap(banner).bright
    end
  end
end
