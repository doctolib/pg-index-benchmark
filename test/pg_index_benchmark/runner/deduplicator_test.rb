# frozen_string_literal: true

require_relative "../../test_helper.rb"

module PgIndexBenchmark
  module Runner
    class DeduplicatorTest < Minitest::Test
      def test_simple_case
        table_to_consider = :some_table
        queries = [
          "SELECT 1 from some_table;",
          "SELECT 2 from some_table;",
          "SELECT 1 from other_table;"
        ]
        expected_dedup = ["SELECT 1 from some_table;"]
        run_dedup(table_to_consider, queries, expected_dedup)
      end

      def test_more_complex_cases
        table_to_consider = :books
        queries = [
          "SELECT count(*) from books;",
          "SELECT book, store from books where title = 'Lord of the ring';",
          "SELECT book, store from books where title = 'Mastering PostgreSQL';",
          "SELECT 1 from authors;"
        ]
        expected_dedup = [
          "SELECT count(*) from books;",
          "SELECT book, store from books where title = 'Lord of the ring';"
        ]
        run_dedup(table_to_consider, queries, expected_dedup)
      end

      private

      def run_dedup(table_to_consider, queries, expected_dedup)
        Tempfile.create("queries.sql") do |file|
          queries.each { |query| file.write("#{query}\n") }
          file.flush
          dedup =
            Deduplicator.new(
              { table_name: table_to_consider },
              file.path
            ).validate_config
          dedup.run
          puts dedup.output_path
          assert_equal expected_dedup,
                       File.read(dedup.output_path).lines(chomp: true)
        ensure
          File.delete(dedup.output_path) if FileTest.exist?(dedup.output_path)
        end
      end
    end
  end
end
