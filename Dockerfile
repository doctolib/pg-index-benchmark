FROM ruby:4.0.6@sha256:32f8add871de953cd0123a1416e10d0659ffb5c1804f33c7ca055d7b219ebc1f
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
