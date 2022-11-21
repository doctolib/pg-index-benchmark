FROM ruby:3.1.2

RUN bundle config --global frozen 1

WORKDIR /usr/src/app

COPY ./Gemfile .
COPY ./Gemfile.lock .

RUN bundle install

COPY ./index_benchmark.rb .
COPY ./index_benchmark_tool.rb .
COPY ./query_file_reader.rb .
COPY ./config_loader.rb .

CMD ["./index_benchmark.rb", "-h"]
