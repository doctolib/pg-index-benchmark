# frozen_string_literal: true
Gem::Specification.new do |s|
  s.name = "pg_index_benchmark"
  s.version = '0.0.0'
  s.summary = "Benchmark Aurora PG indexes."

  s.description = <<-DESCRIPTION
    Pg-index-benchmark helps to benchmark the index changes you could do on Aurora PostgreSQL instances.
DESCRIPTION
  s.platform = Gem::Platform::RUBY
  s.required_ruby_version = ">= 3.1.2"
  s.authors = ["Emmanuel Quincerot"]
  s.email = "emmanuel.quincerot@doctolib.com"
  s.files = Dir.glob("{lib}/**/*", File::FNM_DOTMATCH)

  s.extra_rdoc_files = %w[LICENSE README.md]
  s.homepage = "https://github.com/doctolib/pg-index-benchmark"
  s.licenses = ["MIT"]
  s.bindir = "exe"
  s.executables = ["pg-index-benchmark"]

  s.add_runtime_dependency('rainbow', '>= 2.2.2', '< 4.0')
#  s.metadata = {
#    "source_code_uri" => "https://github.com/rubocop/rubocop/",
#    "bug_tracker_uri" => "https://github.com/rubocop/rubocop/issues",
#  }
 # s.add_runtime_dependency('activesupport')
 # s.add_runtime_dependency('digest')
 # s.add_runtime_dependency('json')
 # s.add_runtime_dependency('optparse')
 # s.add_runtime_dependency('pg')
 # s.add_runtime_dependency('pg_query')
 # s.add_runtime_dependency('set')
 # s.add_runtime_dependency('yaml')
#
 # s.add_development_dependency("bundler", ">= 1.15.0", "< 3.0")
  #
  #
  # gem build pg_index_benchmark.gemspec && gem install ./pg_index_benchmark-0.0.0.gem
  # irb
  # require "pg_index_benchmark"
  # PgIndexBenchmark.hi
end
# https://guides.rubygems.org/make-your-own-gem/#your-first-gem