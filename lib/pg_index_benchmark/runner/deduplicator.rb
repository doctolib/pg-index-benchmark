module PgIndexBenchmark
  module Runner
    class Deduplicator
      def initialize(config, file_path)
        puts config
        @file_path = file_path
        @table_name = config[:table_name]
      end
      def validate_config
        raise 'Missing table_name or source_file. Check help' if (@table_name&.empty? || @file_path&.empty?)
        self
      end
      def run
        output_path =
          @file_path.gsub(/\.([^.]+)$/) { ".unique.#{Regexp.last_match(1)}" }

        read_query_count = 0
        unique_fingerprint = Set.new
        ignored_fingerprint = []
        kept_queries = []

        puts "Unique queries will be put in #{output_path}"
        puts "Only queries using \"#{@table_name}\" table will be considered."

        QueryFileReader
          .new(@file_path)
          .parse do |query|
            read_query_count += 1

            # Skip queries that were already parsed or ignored
            begin
              fingerprint = PgQuery.fingerprint(query)
            rescue StandardError => err
              puts "Enable to parse #{query}"
              raise err
            end
            if ignored_fingerprint.include?(fingerprint) ||
                 unique_fingerprint.include?(fingerprint)
              next
            end

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
        File.open(output_path, "w") do |output|
          output.puts(
            kept_queries.join(
              "
            "
            )
          )
        end
        puts "Done"
      end
    end
  end
end
