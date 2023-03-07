# frozen_string_literal: true
require_relative 'option_parser'
module PgIndexBenchmark
  class CLI
    attr_reader :options

    def initialize
      @options = {}
    end
    def run(args = ARGV)
      puts ARGF
      @options, _paths = PgIndexBenchmark::OptionParser.new.parse(args)
      puts "Options are:"
      puts @options
      #TODO
    end
  end
end
