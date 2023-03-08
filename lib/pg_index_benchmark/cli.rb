# frozen_string_literal: true
require_relative "cli/option_parser"
module PgIndexBenchmark
  class CLI
    attr_reader :options

    def initialize
      @options = {}
    end
    def run(args = ARGV)
      @options, _paths = PgIndexBenchmark::OptionParser.new.parse(args)
      puts "Options are:"
      puts @options
      #TODO
    end
  end
end
