# 1) Stage de Node: instala Node.js y PNPM
FROM node:23-alpine AS node
ARG PNPM_VERSION="10.2.0"
RUN npm install -g pnpm@${PNPM_VERSION} \
  && pnpm --version

# 2) Pre-builder: gems + assets
FROM ruby:3.4.4-alpine3.21 AS pre-builder

# Variables de entorno / build args
ARG BUNDLE_WITHOUT="development:test"
ARG RAILS_ENV="production"
ENV BUNDLE_WITHOUT=${BUNDLE_WITHOUT} \
    RAILS_ENV=${RAILS_ENV} \
    BUNDLER_VERSION=2.5.11 \
    BUNDLE_PATH="/gems" \
    NODE_OPTIONS="--max-old-space-size=4096 --openssl-legacy-provider" \
    PNPM_HOME="/root/.local/share/pnpm" \
    PATH="$PNPM_HOME:$PATH"

# Dependencias base (sin Node.js ni npm)
RUN apk update && apk add --no-cache \
    openssl \
    tar \
    build-base \
    tzdata \
    postgresql-dev \
    postgresql-client \
    git \
    curl \
    vips \
  && gem install bundler -v ${BUNDLER_VERSION}

WORKDIR /app

# Copia y bundle gems
COPY Gemfile Gemfile.lock ./
RUN bundle config set force_ruby_platform true \
  && bundle install --jobs 4 --retry 3

# Copia y usa PNPM del stage `node`
COPY --from=node /usr/local /usr/local

# JS deps + build assets
COPY package.json pnpm-lock.yaml ./
RUN pnpm install \
  && SECRET_KEY_BASE=precompile_placeholder RAILS_LOG_TO_STDOUT=enabled \
     bundle exec rake assets:precompile \
  && rm -rf node_modules tmp/cache

# Código de la app
COPY . .
RUN mkdir -p log \
  && git rev-parse HEAD > .git_sha \
  && rm -rf .git .gitignore \
  && rm -rf /gems/ruby/*/cache/*.gem /gems/ruby/*/gems/*/{*.c,*.o}

# 3) Stage final: sólo Ruby + copia todo listo
FROM ruby:3.4.4-alpine3.21

ARG BUNDLE_WITHOUT="development:test"
ENV BUNDLE_WITHOUT=${BUNDLE_WITHOUT} \
    BUNDLER_VERSION=2.5.11 \
    RAILS_ENV=production \
    BUNDLE_PATH="/gems" \
    RAILS_SERVE_STATIC_FILES=true \
    EXECJS_RUNTIME="Disabled"

# Dependencias mínimas
RUN apk update && apk add --no-cache \
    openssl \
    tzdata \
    postgresql-client \
    imagemagick \
    git \
    vips \
  && gem install bundler -v ${BUNDLER_VERSION}

WORKDIR /app
# Copia gems, app y .git_sha desde pre-builder
COPY --from=pre-builder /gems /gems
COPY --from=pre-builder /app /app

EXPOSE 3000
CMD ["bundle", "exec", "rails", "s", "-b", "0.0.0.0"]
