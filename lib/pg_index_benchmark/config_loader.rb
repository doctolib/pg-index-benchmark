# frozen_string_literal: true
require 'yaml'
module PgIndexBenchmark
  class ConfigLoader
    attr_accessor :input_file_path,
                  :only_query_fingerprint,
                  :query_prerun_count,
                  :max_queries_per_scenario,
                  :db_host,
                  :db_port,
                  :db_name,
                  :db_user,
                  :db_password
    def initialize(config_path)
      @config = YAML.load_file(config_path)

      @db_host = ENV.fetch("POSTGRES_HOST", "localhost")
      @db_port = ENV.fetch("POSTGRES_PORT", "5432")
      @db_name = ENV.fetch("POSTGRES_DATABASE", "postgres")
      @db_user = ENV.fetch("POSTGRES_USER", "postgres")
      @db_password = ENV.fetch("POSTGRES_PASSWORD", nil)
    end

    def common_indexes
      @config["common_indexes"] || []
    end

    def scenarios
      @config["scenarios"] || []
    end

    def table_name
      @config["table_name"]
    end

    def validate
      raise "Missing input_file" if @input_file_path&.empty?
      unless common_indexes
        puts "Warning: no common_indexes are defined in config file"
      end
      unless scenarios["reference"]
        puts "Warning: no indexes are defined for reference scenario in config file"
      end
      raise "Config: Missing table_name at root level" unless table_name

      raise "Config: Missing scenarios" unless scenarios

      unless scenarios.size
        raise "Config: Provide alternatives to the reference scenario"
      end
    end
  end
end
