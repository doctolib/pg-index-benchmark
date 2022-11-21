FROM ruby:3.1.2

RUN bundle config --global frozen 1

WORKDIR /usr/src/app

COPY ./benchmark_tool/Gemfile .
COPY ./benchmark_tool/Gemfile.lock .

RUN bundle install

COPY ./index_benchmark.rb .
COPY ./index_benchmark_tool.rb .
COPY ./query_file_reader.rb .

CMD ["./index_benchmark.rb", "-h"]
