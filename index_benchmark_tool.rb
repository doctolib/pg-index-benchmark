# frozen_string_literal: true
require 'pg'
require 'pg_query'
require 'set'
require 'json'
require 'digest/sha1'

class IndexBenchmarkTool
  EXPLAIN_PLAN_FIELDS_TO_EXTRACT = [
    'Actual Total Time',
    'Total Cost',
    'Shared Hit Blocks',
    'Shared Read Blocks',
    'Actual Rows',
  ].freeze

  def initialize(config)
    @result_plans = {}
    @queries_by_fingerprint = {}
    @queries_run_in_scenario = 0

    @not_impacted_queries = []
    %i[
      db_host
      db_port
      db_name
      db_user
      db_password
      scenarios
      table_name
      common_indexes
      query_prerun_count
      only_query_fingerprint
      input_file_path
      max_queries_per_scenario
    ].each { |field| instance_variable_set("@#{field}", config.send(field)) }
  end

  def deduplicate
    output_path = @input_file_path.gsub(/\.([^.]+)$/) { ".unique.#{Regexp.last_match(1)}" }

    read_query_count = 0
    unique_fingerprint = Set.new
    ignored_fingerprint = []
    kept_queries = []

    puts "Unique queries will be put in #{output_path}"
    puts "Only queries using \"#{@table_name}\" table will be considered."

    QueryFileReader
      .new(@input_file_path)
      .parse do |query|
        read_query_count += 1

        # Skip queries that were already parsed or ignored
        begin
          fingerprint = PgQuery.fingerprint(query)
        rescue StandardError => err
          puts "Enable to parse #{query}"
          raise err
        end
        next if ignored_fingerprint.include?(fingerprint) || unique_fingerprint.include?(fingerprint)

        # Ignore queries that are not related to table_name
        if PgQuery.parse(query).tables.include?(@table_name.to_s)
          unique_fingerprint << fingerprint
          kept_queries << query
        else
          ignored_fingerprint << fingerprint
        end
      end

    puts "Total #{read_query_count} queries using (#{unique_fingerprint.size} unique using #{@table_name})"
    puts "Writing to #{output_path}..."
    File.open(output_path, 'w') do |output|
      output.puts(
        kept_queries.join(
          '
          ',
        ),
      )
    end
    puts 'Done'
  end

  def run_benchmark
    related_query = nil
    if @only_query_fingerprint
      QueryFileReader
        .new(@input_file_path)
        .parse do |query|
          fingerprint = fingerprint(query)
          next if fingerprint != @only_query_fingerprint
          related_query = query
          break
      end
      raise "Could not run only query #{@only_query_fingerprint}. Query not found in #{@input_file_path}" if related_query.nil?
      puts "Full details for query #{@only_query_fingerprint}: #{related_query}"
    end
    @scenarios.each_key { |scenario_key| benchmark(scenario_key, related_query) }

    report
  end

  def report
    if @only_query_fingerprint
      @result_plans[@only_query_fingerprint].each do |scenario, plan|
        puts "---- Plan for #{scenario} ----\n#{plan}\n\n"
      end
      return
    end

    @not_impacted_queries = []
    @queries_by_fingerprint.each_key { |fingerprint| report_for_query fingerprint }

    unless @not_impacted_queries.empty?
      puts "For these queries each scenario was using the same indexes: #{@not_impacted_queries.join(' ')}\n"
    end
    puts "\nTo get the detailed execution plan for a specific query, use '-q QUERY_ID'"
  end

  private

  def report_for_query(fingerprint)
    indexes_by_scenario = {}
    query_text = @queries_by_fingerprint[fingerprint]
    plans_for_query = @result_plans[fingerprint]
    @scenarios.each_key do |scenario|
      indexes_by_scenario[scenario] = used_indexes(plans_for_query[scenario].to_s).sort.join(', ')
    end

    impacted_scenarios =
      (@scenarios.keys - ['reference']).reject do |scenario|
        indexes_by_scenario[scenario] == indexes_by_scenario['reference']
      end

    if impacted_scenarios.empty?
      @not_impacted_queries << fingerprint
      return
    end

    scenarios_to_display = ['reference'] + impacted_scenarios
    not_impacted_scenarios = @scenarios.keys - scenarios_to_display

    puts '----------------------------------------------------'
    puts "Query #{fingerprint}:"
    puts query_text.to_s
    EXPLAIN_PLAN_FIELDS_TO_EXTRACT.each { |field| compare_plan_results(impacted_scenarios, plans_for_query, field) }

    puts
    puts 'Used indexes:'
    scenarios_to_display.each { |scenario| puts strings_in_columns(scenario, indexes_by_scenario[scenario]) }

    puts "Not impacted scenarios: #{not_impacted_scenarios.join(' ')}" unless not_impacted_scenarios.empty?

    puts ''
  end

  def fingerprint(query)
    Digest::SHA1.hexdigest(query)
  end

  def used_indexes(execution_plan)
    execution_plan.scan(/"Index Name"=>"(\w+)"/)
  end

  def strings_in_columns(column1, column2)
    @column_length ||= @scenarios.keys.map(&:length).max + 1
    "  #{column1.to_s.ljust(@column_length, ' ')} #{column2}"
  end

  def connection
    @connection ||=
      begin
        puts "Connecting to #{@db_user}@#{@db_host}:#{@db_port}/#{@db_name} ..."
        PG.connect(
          host: @db_host,
          port: @db_port,
          dbname: @db_name,
          user: @db_user,
          password: @db_password,
          connect_timeout: 2,
        )
      end
  end

  def json_plan(query)
    @query_prerun_count.times { connection.exec(query) }
    json_plan = connection.exec("EXPLAIN (FORMAT JSON, ANALYZE, BUFFERS, VERBOSE) #{query}").first.first[1]
    JSON.parse(json_plan).first['Plan']
  end

  def raw_plan(query)
    json_plan = connection.exec("EXPLAIN (ANALYZE, BUFFERS, VERBOSE) #{query}").values
    json_plan.join(
      '
      ',
    )
  end

  def existing_indexes(table_name)
    result = connection.exec("select indexname from pg_indexes where tablename = '#{table_name}'")
    result.values.map(&:first)
  end

  def drop_indexes(indexes)
    puts "  - Dropping #{indexes.size} indexes: #{indexes.join(' ')}"
    indexes.each { |index| connection.exec("DROP INDEX IF EXISTS \"#{index}\"") }
  end

  def benchmark(scenario, only_query_text = nil)
    puts "\n- Playing scenario: #{scenario}"
    connection.exec('BEGIN')

    scenario_indexes_to_keep = @scenarios[scenario] || []
    puts "  - Adding indexes to reference: #{scenario_indexes_to_keep.join(' ')}"
    index_to_drop =
      existing_indexes(@table_name)
        .reject { |index| @common_indexes.include?(index) }
        .reject { |index| scenario_indexes_to_keep.include?(index) }

    drop_indexes(index_to_drop)

    if only_query_text.nil?
      message = @query_prerun_count > 0 ? "  - Running queries (#{@query_prerun_count} times each)..." : "- Running queries..."
      puts message
      @queries_run_in_scenario = 0
      QueryFileReader.new(@input_file_path).parse do |query|
        if @queries_run_in_scenario > @max_queries_per_scenario
          puts "Max queries per scenario (#{@max_queries_per_scenario}) reached. Other queries are ignored"
          return
        end
        run_query_for_scenario(scenario, query, :json)
      end
      raise "Error: no valid queries found in #{@input_file_path}. Make sure queries are valid and end with ';'" if @queries_run_in_scenario == 0
      puts "  - #{@queries_run_in_scenario} queries run"
    else
      run_query_for_scenario(scenario, only_query_text, :raw)
    end
  ensure
    connection.exec('ROLLBACK')
  end

  def run_query_for_scenario(scenario, query_text, format = :json)
    tables = PgQuery.parse(query_text).tables
    unless tables.include?(@table_name)
      puts "Ignoring query not using #{@table_name}: #{query_text}" if scenario == 'reference'
      return
    end
    @queries_run_in_scenario += 1

    # Show progression every 50 queries
    puts "... #{@queries_run_in_scenario} queries run" if @queries_run_in_scenario % 50 == 0

    fingerprint = fingerprint(query_text)
    @queries_by_fingerprint[fingerprint] = query_text unless @queries_by_fingerprint.key?(fingerprint)
    plan =
      (
        if format == :json
          json_plan(query_text)
        else
          raw_plan(query_text)
        end
      )
    @result_plans[fingerprint] = {} unless @result_plans.key?(fingerprint)
    @result_plans[fingerprint][scenario] = plan
  end

  def compare_plan_results(impacted_scenarios, query_hash, field)
    reference = query_hash['reference'][field]
    alternative_results = []
    impacted_scenarios.each do |alternative_key|
      alternative_result = query_hash[alternative_key][field]
      emoji = alternative_result.to_f > reference.to_f ? '❌️' : '✅'
      alternative_results << strings_in_columns(alternative_key, "#{alternative_result} #{emoji}")
    end
    puts "\n#{field}:"
    puts strings_in_columns('reference', reference)
    alternative_results.each { |r| puts r }
  end

  def plan_value(scenario, query_fingerprint, plan_field)
    @result_plans[query_fingerprint][scenario][plan_field]
  end
end
