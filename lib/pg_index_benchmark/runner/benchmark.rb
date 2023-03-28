# frozen_string_literal: true
require "pg"
module PgIndexBenchmark
  module Runner
    class Benchmark
      EXPLAIN_PLAN_FIELDS_TO_EXTRACT = [
        "Actual Total Time",
        "Total Cost",
        "Shared Hit Blocks",
        "Shared Read Blocks",
        "Actual Rows"
      ].freeze

      def initialize(options, query_file_path)
        init_benchmark_results
        load_options(options, query_file_path)
        load_config_values
      end

      def validate_config
        @config.validate
        self
      end

      def run
        related_query = nil
        if @only_query_fingerprint
          related_query = query_to_run(@only_query_fingerprint)
        end

        @scenarios.each_key do |scenario_key|
          STDOUT.flush
          benchmark(scenario_key, related_query)
        end

        report
      end

      private

      def init_benchmark_results
        @result_plans = {}
        @queries_by_fingerprint = {}
        @queries_run_in_scenario = 0
        @not_impacted_queries = []
      end

      def load_config_values
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
        ].each do |field|
          instance_variable_set("@#{field}", @config.send(field))
        end
      end

      def load_options(options, query_file_path)
        @config =
          PgIndexBenchmark::ConfigLoader.new(
            options[:config_path] || "config.yml"
          )
        @config.input_file_path = query_file_path
        @config.query_prerun_count = options[:times]&.to_i || 0
        @config.max_queries_per_scenario =
          options[:max_queries_per_scenario]&.to_i || 500
        @config.only_query_fingerprint =
          options[:only_query_fingerprint] if options[:only_query_fingerprint]
      end

      def query_to_run(query_fingerprint)
        QueryFileReader
          .new(@input_file_path)
          .parse do |query|
            fingerprint = fingerprint(query)
            next if fingerprint != query_fingerprint
            puts "Full details for query #{query_fingerprint}: #{query}"
            return query
          end
        raise "Could not run only query #{query_fingerprint}. Query not found in #{@input_file_path}"
      end

      def report
        if @only_query_fingerprint
          @result_plans[@only_query_fingerprint].each do |scenario, plan|
            puts "---- Plan for #{scenario} ----\n#{plan}\n\n"
          end
          return
        end

        @not_impacted_queries = []
        @queries_by_fingerprint.each_key do |fingerprint|
          report_for_query fingerprint
        end

        unless @not_impacted_queries.empty?
          puts "For these queries each scenario was using the same indexes: #{@not_impacted_queries.join(" ")}\n"
        end
        puts "\nTo get the detailed execution plan for a specific query, use '-q QUERY_ID'"
      end

      def report_for_query(fingerprint)
        indexes_by_scenario = {}
        query_text = @queries_by_fingerprint[fingerprint]
        plans_for_query = @result_plans[fingerprint]
        @scenarios.each_key do |scenario|
          indexes_by_scenario[scenario] = used_indexes(
            plans_for_query[scenario].to_s
          ).sort.join(", ")
        end

        impacted_scenarios =
          (@scenarios.keys - ["reference"]).reject do |scenario|
            indexes_by_scenario[scenario] == indexes_by_scenario["reference"]
          end

        if impacted_scenarios.empty?
          @not_impacted_queries << fingerprint
          return
        end

        scenarios_to_display = ["reference"] + impacted_scenarios
        not_impacted_scenarios = @scenarios.keys - scenarios_to_display

        puts "----------------------------------------------------"
        puts "Query #{fingerprint}:"
        puts query_text.to_s
        EXPLAIN_PLAN_FIELDS_TO_EXTRACT.each do |field|
          compare_plan_results(impacted_scenarios, plans_for_query, field)
        end

        puts
        puts "Used indexes:"
        scenarios_to_display.each do |scenario|
          puts strings_in_columns(scenario, indexes_by_scenario[scenario])
        end

        unless not_impacted_scenarios.empty?
          puts "Scenarios without impact: #{not_impacted_scenarios.join(" ")}"
        end

        puts ""
      end

      def fingerprint(query)
        Digest::SHA1.hexdigest(query)
      end

      def used_indexes(execution_plan)
        execution_plan.scan(/"Index Name"=>"(\w+)"/)
      end

      def strings_in_columns(column1, column2)
        @column_length ||= @scenarios.keys.map(&:length).max + 1
        "  #{column1.to_s.ljust(@column_length, " ")} #{column2}"
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
              connect_timeout: 2
            )
          end
      end

      def json_plan(query)
        @query_prerun_count.times { connection.exec(query) }
        json_plan =
          connection
            .exec("EXPLAIN (FORMAT JSON, ANALYZE, BUFFERS, VERBOSE) #{query}")
            .first
            .first[
            1
          ]
        JSON.parse(json_plan).first["Plan"]
      end

      def raw_plan(query)
        json_plan =
          connection.exec("EXPLAIN (ANALYZE, BUFFERS, VERBOSE) #{query}").values
        json_plan.join(
          "
        "
        )
      end

      def existing_indexes(table_name)
        result =
          connection.exec(
            "select indexname from pg_indexes where tablename = '#{table_name}';"
          )
        result.values.map(&:first)
      end

      def drop_indexes(indexes)
        puts "  - Dropping #{indexes.size} indexes: #{indexes.join(" ")}"
        indexes.each do |index|
          connection.exec("DROP INDEX IF EXISTS \"#{index}\";")
        end
      end

      def benchmark(scenario, only_query_text = nil)
        puts "\n- Playing scenario: #{scenario}"
        connection.exec("BEGIN;")

        drop_indexes(indexes_to_drop(scenario))

        if only_query_text.nil?
          puts (
                 if @query_prerun_count > 0
                   "  - Running queries (#{@query_prerun_count + 1} times each)..."
                 else
                   "  - Running queries..."
                 end
               )
          @queries_run_in_scenario = 0
          QueryFileReader
            .new(@input_file_path)
            .parse do |query|
              if @queries_run_in_scenario > @max_queries_per_scenario
                puts "Max queries per scenario (#{@max_queries_per_scenario}) reached. Other queries are ignored"
                return
              end
              run_query_for_scenario(scenario, query, :json)
            end
          if @queries_run_in_scenario == 0
            raise "Error: no valid queries found in #{@input_file_path}. Make sure queries are valid and end with ';'"
          end
          puts "  - #{@queries_run_in_scenario} queries run"
        else
          run_query_for_scenario(scenario, only_query_text, :raw)
        end
        connection.exec("ROLLBACK;")
      end

      def indexes_to_drop(scenario)
        scenario_indexes_to_keep = @scenarios[scenario] || []
        puts "  - Adding indexes to reference: #{scenario_indexes_to_keep.join(" ")}"
        existing_indexes(@table_name)
          .reject { |index| @common_indexes.include?(index) }
          .reject { |index| scenario_indexes_to_keep.include?(index) }
      end

      def run_query_for_scenario(scenario, query_text, format = :json)
        tables = PgQuery.parse(query_text).tables
        unless tables.include?(@table_name)
          if scenario == "reference"
            puts "Ignoring query not using #{@table_name}: #{query_text}"
          end
          return
        end
        @queries_run_in_scenario += 1

        # Show progression every 50 queries
        if @queries_run_in_scenario % 50 == 0
          puts "... #{@queries_run_in_scenario} queries run"
        end

        fingerprint = fingerprint(query_text)
        @queries_by_fingerprint[
          fingerprint
        ] = query_text unless @queries_by_fingerprint.key?(fingerprint)
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
        reference = query_hash["reference"][field]
        alternative_results = []
        impacted_scenarios.each do |alternative_key|
          alternative_result = query_hash[alternative_key][field]
          emoji = alternative_result.to_f > reference.to_f ? "❌️" : "✅"
          alternative_results << strings_in_columns(
            alternative_key,
            "#{alternative_result} #{emoji}"
          )
        end
        puts "\n#{field}:"
        puts strings_in_columns("reference", reference)
        alternative_results.each { |r| puts r }
      end

      def plan_value(scenario, query_fingerprint, plan_field)
        @result_plans[query_fingerprint][scenario][plan_field]
      end
    end
  end
end
