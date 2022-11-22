# frozen_string_literal: true
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

    @db_host = ENV.fetch('POSTGRES_HOST', 'localhost')
    @db_port = ENV.fetch('POSTGRES_PORT', '5432')
    @db_name = ENV.fetch('POSTGRES_DATABASE', 'postgres')
    @db_user = ENV.fetch('POSTGRES_USER', 'postgres')
    @db_password = ENV.fetch('POSTGRES_PASSWORD', nil)
  end

  def common_indexes
    @config['common_indexes'] || []
  end

  def scenarios
    @config['scenarios'] || []
  end

  def table_name
    @config['table_name']
  end

  def check
    raise 'Missing input_file' if @input_file_path.blank?
    puts 'Warning: no common_indexes are defined in config file' unless common_indexes
    puts 'Warning: no indexes are defined for reference scenario in config file' unless scenarios['reference']
    raise 'Config: Missing table_name at root level' unless table_name

    raise 'Config: Missing scenarios' unless scenarios

    raise 'Config: Provide alternatives to the reference scenario' unless scenarios.size
  end
end
