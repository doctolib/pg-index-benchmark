#!/usr/bin/env ruby
# frozen_string_literal: true
require 'optparse'
require_relative 'index_benchmark_tool'
require_relative 'query_file_reader'
require_relative 'config_loader'
require 'active_support'
require 'yaml'

options = { mode: :benchmark }
parser =
  OptionParser.new do |parser|
    parser.banner = [
      'Run queries and compare their plans with multiple index scenarios',
      '',
      "USAGE: #{__FILE__} [ --help ] [ -q query_fingerprint ] [input_file.sql]",
      '',
      'The input file should contain the list of queries to use for the benchmark. Multiline queries are allowed, but should be separated with a ;',
      ' ',
      ' ',
      'Connection config:',
      'By default, the localhost connection is used on local port. Override the environment variables to connect to other db: POSTGRES_HOST, POSTGRES_PORT, POSTGRES_DATABASE, POSTGRES_USER, POSTGRES_PASSWORD',
    ].join(
      '
      ',
    )

    parser.on('-h', '--help', 'Prints this help') do
      puts parser
      exit
    end

    parser.on(
      '-d',
      '--deduplicate-only',
      'Only deduplicate queries from input file, and copy them when they are related to table_name',
    ) { options[:mode] = :deduplicate }

    parser.on(
      '-n times',
      '--load-cache-run times',
      'Run each query n times priori to get the plan, in order to have an up to date cache',
    ) { |times| options[:times] = times }

    parser.on(
      '-q query_fingerprint',
      '--only-query=query_fingerprint',
      'Benchmark only the query matching query_fingerprint',
    ) { |fingerprint| options[:only_query_fingerprint] = fingerprint }

    parser.on(
      '-c config_file.yml',
      '--config=config_file.yml',
      'Specify the config file instead of config_file.yml',
    ) { |config_path| options[:config_path] = config_path }

    parser.on(
      '-m n',
      '--max-queries-per-scenario=n',
      'Specify the max queries to run per scenario. If this amount is reached further queries will be ignored',
      ) { |n| options[:max_queries_per_scenario] = n }
  end

other_args = parser.parse!

config = ConfigLoader.new(options[:config_path] || 'config.yml')
config.input_file_path = other_args[0]
config.query_prerun_count = options[:times]&.to_i || 0
config.max_queries_per_scenario = options[:max_queries_per_scenario]&.to_i || 500
config.only_query_fingerprint = options[:only_query_fingerprint] if options[:only_query_fingerprint]

config.check
benchmark_tool = IndexBenchmarkTool.new(config)

options[:mode] == :deduplicate ? benchmark_tool.deduplicate : benchmark_tool.run_benchmark
