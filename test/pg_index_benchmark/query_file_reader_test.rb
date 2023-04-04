# frozen_string_literal: true
require_relative "../test_helper.rb"

class PgIndexBenchmark::QueryFileReaderTest < Minitest::Test
  describe "when parsing queries" do
    it "queries are split correctly" do
      expected_queries = [
        "SELECT * from books;",
        "SELECT * from agendas;",
        "SELECT * from authors;",
        "SELECT * from multilines;"
      ]
      PgIndexBenchmark::QueryFileReader
        .new("test/pg_index_benchmark/fixtures/queries.sql")
        .parse { |query| assert_equal expected_queries.shift, query }
    end
  end
end
