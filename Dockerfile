FROM ruby:3.4.10@sha256:a9d6c36be5d7bc09d275b6df5eba2e98db2e35fcfe132f1fd23cddd91e2d674b
WORKDIR /usr/src/app

ADD Gemfile Gemfile.lock pg_index_benchmark.gemspec /usr/src/app/

RUN bundle config --global frozen 1
RUN bundle install

COPY exe /usr/src/app/exe
COPY lib /usr/src/app/lib
COPY LICENSE README.md /usr/src/app/

RUN gem build pg_index_benchmark.gemspec
RUN gem install -l './pg_index_benchmark-0.0.0.gem'

ENTRYPOINT ["pg-index-benchmark"]
CMD ["-h"]
