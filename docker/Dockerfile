# 1) Node stage: instala Node.js y PNPM
FROM node:23-alpine AS node

ARG PNPM_VERSION="10.2.0"
RUN npm install -g pnpm@${PNPM_VERSION} \
  && pnpm --version

# 2) Pre-builder stage: gems, JS deps y compilación de assets
FROM ruby:3.4.4-alpine3.21 AS pre-builder

ARG BUNDLE_WITHOUT="development:test"
ARG RAILS_ENV="production"
ARG BUNDLER_VERSION="2.5.11"

ENV BUNDLE_WITHOUT=${BUNDLE_WITHOUT} \
    RAILS_ENV=${RAILS_ENV} \
    BUNDLER_VERSION=${BUNDLER_VERSION} \
    BUNDLE_PATH="/gems" \
    NODE_OPTIONS="--max-old-space-size=4096 --openssl-legacy-provider" \
    PNPM_HOME="/root/.local/share/pnpm" \
    PATH="$PNPM_HOME:$PATH" \
    HUSKY=0

WORKDIR /app

# Dependencias de sistema e instalador de Bundler
RUN apk update && apk add --no-cache \
    build-base \
    curl \
    git \
    linux-headers \
    libffi-dev \
    pkgconf \
    postgresql-dev \
    postgresql-client \
    tar \
    tzdata \
    vips \
    openssl \
    gcompat \
  && gem install bundler -v ${BUNDLER_VERSION}

# Instalación de gems
COPY Gemfile Gemfile.lock ./
RUN bundle config set force_ruby_platform true \
  && bundle install --jobs 4 --retry 3

# Traer PNPM desde el stage de Node
COPY --from=node /usr/local /usr/local

# Copiar código y compilar assets
COPY . .
RUN pnpm install \
  && SECRET_KEY_BASE=precompile_placeholder RAILS_LOG_TO_STDOUT=enabled \
     bundle exec rake assets:precompile \
  && rm -rf node_modules tmp/cache

# Limpieza de cachés y metadatos
RUN mkdir -p log \
  && git rev-parse HEAD > .git_sha \
  && rm -rf .git .gitignore \
  && rm -rf /gems/ruby/*/cache/*.gem \
  && find /gems/ruby/*/gems -type f \( -name "*.c" -o -name "*.o" \) -delete

# 3) Final stage: runtime minimal
FROM ruby:3.4.4-alpine3.21

ARG BUNDLE_WITHOUT="development:test"
ARG BUNDLER_VERSION="2.5.11"

ENV BUNDLE_WITHOUT=${BUNDLE_WITHOUT} \
    BUNDLER_VERSION=${BUNDLER_VERSION} \
    RAILS_ENV="production" \
    BUNDLE_PATH="/gems" \
    RAILS_SERVE_STATIC_FILES=true \
    EXECJS_RUNTIME="Disabled"

WORKDIR /app

# Dependencias mínimas de runtime
RUN apk update && apk add --no-cache \
    git \
    imagemagick \
    postgresql-client \
    tzdata \
    vips \
    openssl \
    gcompat \
  && gem install bundler -v ${BUNDLER_VERSION}

# Copiar gems y aplicación compilada
COPY --from=pre-builder /gems /gems
COPY --from=pre-builder /app /app

EXPOSE 3000
CMD ["bundle", "exec", "rails", "s", "-b", "0.0.0.0"]
