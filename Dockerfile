FROM ruby:3.1.2

WORKDIR /usr/src/app

ADD Gemfile Gemfile.lock /usr/src/app/

RUN bundle config --global frozen 1
RUN bundle install

ADD run.rb index_benchmark_tool.rb query_file_reader.rb config_loader.rb /usr/src/app/

ENTRYPOINT ["/usr/src/app/run.rb"]
CMD ["-h"]
