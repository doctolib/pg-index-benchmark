# frozen_string_literal: true

require_relative "../../test_helper.rb"

module PgIndexBenchmark
  module Runner
    class DeduplicatorTest < Minitest::Test
      INPUT_FILE = "test/pg_index_benchmark/fixtures/duplicate_queries.sql"
      OUTPUT_FILE =
        "test/pg_index_benchmark/fixtures/duplicate_queries.unique.sql"

      def teardown
        File.delete(OUTPUT_FILE) if File.exist?(OUTPUT_FILE)
      end

      describe "validation" do
        it "test_validates_correct_config" do
          dedup =
            PgIndexBenchmark::Runner::Deduplicator.new(
              { table_name: "books" },
              INPUT_FILE
            )
          dedup.validate_config
        end

        it "test_validates_raise_on_missing_query_filename" do
          dedup =
            PgIndexBenchmark::Runner::Deduplicator.new(
              { table_name: "books" },
              ""
            )
          e = assert_raises { dedup.validate_config }
          assert_equal "Missing query source file. Check help.", e.message
        end

        it "test_validates_raise_on_invalid_filename" do
          dedup =
            PgIndexBenchmark::Runner::Deduplicator.new(
              { table_name: "books" },
              "not_existing_path"
            )
          e = assert_raises { dedup.validate_config }
          assert_equal "not_existing_path does not exists.", e.message
        end

        it "test_validates_raise_on_missing_table_name" do
          dedup = PgIndexBenchmark::Runner::Deduplicator.new({}, INPUT_FILE)
          e = assert_raises { dedup.validate_config }
          assert_equal "Missing table_name. Check help.", e.message
        end
      end

      describe "deduplicator" do
        it "runs successfully" do
          expected_output = <<-MSG
Unique queries will be put in test/pg_index_benchmark/fixtures/duplicate_queries.unique.sql
Only queries using "books" table will be considered.
Total 6 queries using (3 unique using books)
Writing to test/pg_index_benchmark/fixtures/duplicate_queries.unique.sql...
Done
      MSG

          dedup =
            PgIndexBenchmark::Runner::Deduplicator.new(
              { table_name: "books" },
              INPUT_FILE
            )
          dedup.validate_config
          assert_output(expected_output) { dedup.run }
          assert FileUtils.compare_file(
                   "test/pg_index_benchmark/fixtures/expected_deduplicate_queries.sql",
                   OUTPUT_FILE
                 )
        ensure
          File.delete(OUTPUT_FILE) if File.exist?(OUTPUT_FILE)
        end
      end
    end
  end
end
