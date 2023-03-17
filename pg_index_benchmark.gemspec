# frozen_string_literal: true
Gem::Specification.new do |s|
  s.name = "pg_index_benchmark"
  s.version = '0.0.0'
  s.summary = "Benchmark Aurora PG indexes."

  s.description = <<-DESCRIPTION
    Pg-index-benchmark helps to benchmark the index changes you could do on Aurora PostgreSQL instances.
DESCRIPTION
  s.platform = Gem::Platform::RUBY
  s.required_ruby_version = ">= 3.2.1"
  s.authors = ["Emmanuel Quincerot"]
  s.email = "emmanuel.quincerot@doctolib.com"
  s.files = Dir.glob("{lib}/**/*", File::FNM_DOTMATCH)

  s.extra_rdoc_files = %w[LICENSE README.md]
  s.homepage = "https://github.com/doctolib/pg-index-benchmark"
  s.licenses = ["MIT"]
  s.bindir = "exe"
  s.executables = ["pg-index-benchmark"]

  s.add_runtime_dependency('rainbow', '>= 2.2.2', '< 4.0')
  s.add_runtime_dependency('activesupport', '>= 7.0.4', '< 8.0')
  s.add_runtime_dependency('digest', '>= 3.1.0', '< 4.0')
  s.add_runtime_dependency('json', '>= 2.6.2', '< 3.0')
  s.add_runtime_dependency('optparse', '>= 0.2.0', '< 1.0')
  s.add_runtime_dependency('pg', '>= 1.4.5', '< 2.0')
  s.add_runtime_dependency('pg_query', '>= 2.2.0', '< 3.0')
  s.add_runtime_dependency('set', '>= 1.0.3', '< 2.0')
  s.add_runtime_dependency('yaml', '>= 0.2.0', '< 1.0')
  s.add_runtime_dependency('minitest', '~> 5.16')
  s.add_runtime_dependency('rake', '~> 13.0')
end