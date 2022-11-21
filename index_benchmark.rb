#!/usr/bin/env ruby
# frozen_string_literal: true
require 'optparse'
require_relative 'index_benchmark_tool'
require_relative 'query_file_reader'
require 'active_support'
require 'yaml'

class ConfigLoader
  attr_accessor :input_file_path,
                :only_query_fingerprint,
                :query_prerun_count,
                :db_host,
                :db_port,
                :db_name,
                :db_user,
                :db_password
  def initialize(config_path)
    @config = YAML.load_file(config_path)

    @db_host = ENV.fetch('POSTGRES_HOST', 'localhost')
    @db_port = ENV.fetch('POSTGRES_PORT', '5432')
    @db_name = ENV.fetch('POSTGRES_DATABASE', 'postgres')
    @db_user = ENV.fetch('POSTGRES_USER', 'postgres')
    @db_password = ENV.fetch('POSTGRES_PASSWORD', nil)
  end

  def common_indexes
    @config['common_indexes']
  end

  def scenarios
    @config['scenarios']
  end

  def table_name
    @config['table_name']
  end

  def check
    raise 'Config: Missing table_name at root level' unless table_name
    raise 'Config: Missing common_indexes' unless common_indexes
    raise 'Config: Missing scenarios' unless scenarios
    raise 'Config: Missing reference scenario' unless scenarios['reference']
    raise 'Config: Provide alternatives to the reference scenario' unless scenarios.size
  end
end

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
  end

other_args = parser.parse!
input_file_path = other_args[0]

raise 'Missing input_file' if input_file_path.blank?

config = ConfigLoader.new(options[:config_path] || 'config.yml')
config.input_file_path = input_file_path
config.query_prerun_count = options[:times] || 0
config.only_query_fingerprint = options[:only_query_fingerprint] if options[:only_query_fingerprint]

config.check
benchmark_tool = IndexBenchmarkTool.new(config)

options[:mode] == :deduplicate ? benchmark_tool.deduplicate : benchmark_tool.run_benchmark.report
