ARG RUBY_VERSION=3.3.6
FROM ruby:$RUBY_VERSION-slim AS base

WORKDIR /app

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

COPY bin/docker-entrypoint /usr/bin/docker-entrypoint
RUN chmod +x /usr/bin/docker-entrypoint
ENTRYPOINT ["docker-entrypoint"]
EXPOSE 3000

FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    libpq-dev \
    nodejs \
    git \
    && rm -rf /var/lib/apt/lists/*

FROM build AS development

COPY Gemfile Gemfile.lock ./
RUN bundle lock --add-platform x86_64-linux aarch64-linux && bundle install

COPY . .
RUN bundle exec bootsnap precompile --gemfile app/ lib/

CMD ["rails", "server", "-b", "0.0.0.0"]

FROM build AS gems

ENV RAILS_ENV=production \
    BUNDLE_WITHOUT="development test"

COPY Gemfile Gemfile.lock ./
RUN bundle lock --add-platform x86_64-linux aarch64-linux && \
    bundle install && \
    rm -rf /usr/local/bundle/ruby/*/cache

COPY . .
RUN bundle exec bootsnap precompile --gemfile app/ lib/ && \
    SECRET_KEY_BASE=dummy ./bin/rails assets:precompile

FROM base AS production

ENV RAILS_ENV=production \
    BUNDLE_WITHOUT="development test"

COPY --from=gems /usr/local/bundle /usr/local/bundle
COPY --from=gems /app /app

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p log storage tmp && \
    chown -R rails:rails db log storage tmp
USER rails:rails

CMD ["./bin/rails", "server"]
