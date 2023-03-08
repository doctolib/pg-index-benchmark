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
      puts "Options are:"
      query_file_path = paths[0]
      puts @options, query_file_path
      if @options[:mode] == :deduplicate
        Runner::Deduplicator.new(@options, query_file_path).validate_config.run
      else
        Runner::Benchmark.new(@options, query_file_path).validate_config.run
      end
    end
  end
end
