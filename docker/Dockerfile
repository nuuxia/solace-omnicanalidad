# Pre-build stage
FROM ruby:3.3.3-alpine3.19 AS pre-builder

ARG NODE_VERSION="20.15.1"
ARG PNPM_VERSION="10.2.0"
ARG BUNDLE_WITHOUT="development:test"
ENV BUNDLE_WITHOUT=${BUNDLE_WITHOUT}
ENV BUNDLER_VERSION=2.5.11
ARG RAILS_ENV=production
ENV RAILS_ENV=${RAILS_ENV}
ENV BUNDLE_PATH="/gems"
ENV NODE_OPTIONS="--max-old-space-size=4096 --openssl-legacy-provider"

# Instalar dependencias base + node + npm
RUN apk update && apk add --no-cache \
  openssl \
  tar \
  build-base \
  tzdata \
  postgresql-dev \
  postgresql-client \
  nodejs=${NODE_VERSION}-r0 \
  npm \
  git \
  curl \
  && mkdir -p /var/app \
  && gem install bundler

# Instalar pnpm globalmente
RUN npm install -g pnpm@${PNPM_VERSION} && pnpm --version

ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

WORKDIR /app

COPY Gemfile Gemfile.lock ./

RUN apk add --no-cache \
  build-base musl ruby-full ruby-dev gcc make musl-dev \
  openssl openssl-dev g++ linux-headers xz vips

RUN bundle config set --local force_ruby_platform true

RUN if [ "$RAILS_ENV" = "production" ]; then \
  bundle config set without 'development test'; bundle install -j 4 -r 3; \
  else bundle install -j 4 -r 3; \
  fi

COPY package.json pnpm-lock.yaml ./
RUN pnpm install

COPY . /app
RUN mkdir -p /app/log

RUN if [ "$RAILS_ENV" = "production" ]; then \
  SECRET_KEY_BASE=precompile_placeholder RAILS_LOG_TO_STDOUT=enabled bundle exec rake assets:precompile \
  && rm -rf spec node_modules tmp/cache; \
  fi

RUN git rev-parse HEAD > /app/.git_sha

RUN rm -rf /gems/ruby/3.3.0/cache/*.gem \
  && find /gems/ruby/3.3.0/gems/ \( -name "*.c" -o -name "*.o" \) -delete \
  && rm -rf .git .gitignore

# Final stage
FROM ruby:3.3.3-alpine3.19

ARG NODE_VERSION="20.15.1"
ARG PNPM_VERSION="10.2.0"
ARG BUNDLE_WITHOUT="development:test"
ENV BUNDLE_WITHOUT=${BUNDLE_WITHOUT}
ENV BUNDLER_VERSION=2.5.11
ENV EXECJS_RUNTIME="Disabled"
ENV RAILS_SERVE_STATIC_FILES=true
ENV BUNDLE_FORCE_RUBY_PLATFORM=1
ENV RAILS_ENV=production
ENV BUNDLE_PATH="/gems"

RUN apk update && apk add --no-cache \
  build-base \
  openssl \
  tzdata \
  postgresql-client \
  imagemagick \
  git \
  vips \
  nodejs=${NODE_VERSION}-r0 \
  npm \
  && gem install bundler

# pnpm en no-producción
RUN if [ "$RAILS_ENV" != "production" ]; then \
  npm install -g pnpm@${PNPM_VERSION} && pnpm --version; \
  fi

COPY --from=pre-builder /gems/ /gems/
COPY --from=pre-builder /app /app
COPY --from=pre-builder /app/.git_sha /app/.git_sha

WORKDIR /app

EXPOSE 3000
