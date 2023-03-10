# frozen_string_literal: true
require_relative "cli/option_parser"
module PgIndexBenchmark
  class CLI
    attr_reader :options

    def initialize
      @options = {}
    end
    def run(args = ARGV)
      @options, paths = CLI::OptionParser.new.parse(args)
      query_file_path = paths[0]
      runner.new(@options, query_file_path).validate_config.run
    end

    private

    def runner
      @options[:mode] == :deduplicate ? Runner::Deduplicator : Runner::Benchmark
    end
  end
end
