# frozen_string_literal: true
require "optparse"
require "rainbow"

module PgIndexBenchmark
  class OptionParser
    def parse(args)
      options = { mode: :benchmark }
      parser =
        ::OptionParser.new do |opts|
          add_banner(opts)
          add_help_option(opts)
          add_run_mode(opts)
          add_config(opts)
          add_db_connection(opts)
          add_benchmark_options(opts)
        end
      options[:other_args] = parser.parse!(args)
    end

    private

    def rainbow
      @rainbow ||=
        begin
          rainbow = Rainbow.new
          rainbow.enabled = false if ARGV.include?("--no-color")
          rainbow
        end
    end

    def add_banner(opts)
      opts.banner = rainbow.wrap(<<BANNER).bright
Run queries and compare their plans with multiple index scenarios.

USAGE: #{File.basename($0)} [ --help ] [ -q query_fingerprint ] [input_file.sql]
BANNER
      opts.top.append(
        "The input file should contain the list of queries to use for the benchmark. Multiline queries are allowed, but should be separated with a ;",
        nil,
        nil
      )
    end

    def add_help_option(opts)
      opts.separator("")
      opts.on("-h", "--help", "Prints this help") do
        puts opts
        exit
      end
    end

    def add_config(opts)
      add_header(opts, "Configuration:")
      opts.on(
        "-c config_file.yml",
        "--config=config_file.yml",
        "Specify the config file instead of config_file.yml"
      ) { |config_path| options[:config_path] = config_path }
    end

    def add_db_connection(opts)
      add_header(opts, "Db connection:")
      opts.separator(<<CONTENT)
By default, the localhost connection is used on local port.
Override the environment variables to connect to other db:
  POSTGRES_HOST, POSTGRES_PORT, POSTGRES_DATABASE, POSTGRES_USER, POSTGRES_PASSWORD
CONTENT
    end

    def add_run_mode(opts)
      add_header(opts, "Run mode:", 'By default, benchmark mode is used.')
      opts.on(
        "-d",
        "--deduplicate-only",
        "Only deduplicate queries from input file, and copy them when they are related to table_name"
      ) { options[:mode] = :deduplicate }
    end
    def add_benchmark_options(opts)
      add_header(opts, "Benchmark options:")
      opts.on(
        "-q query_fingerprint",
        "--only-query=query_fingerprint",
        "Benchmark only the query matching query_fingerprint"
      ) { |fingerprint| options[:only_query_fingerprint] = fingerprint }
      opts.on(
        "-n times",
        "--load-cache-run times",
        "Run each query n times priori to get the plan, in order to have an up to date cache"
      ) { |times| options[:times] = times }
      opts.on(
        "-m n",
        "--max-queries-per-scenario=n",
        "Specify the max queries to run per scenario. If this amount is reached further queries will be ignored"
      ) { |n| options[:max_queries_per_scenario] = n }
    end
    def add_header(opts, header, extra_text = nil)
      opts.separator(rainbow.wrap("\n" + header).bright)
      opts.separator(extra_text) if extra_text
    end
  end
end
