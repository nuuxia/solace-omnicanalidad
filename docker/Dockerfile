###################################################################
# 1. Etapa de pre-build (compila gems y JS assets)
###################################################################
FROM ruby:3.3.3-alpine3.19 AS pre-builder

# ──────────── Variables de entorno y args ────────────
ARG BUNDLE_WITHOUT="development:test"
ENV BUNDLE_WITHOUT=${BUNDLE_WITHOUT}
ENV BUNDLER_VERSION=2.5.11

ARG RAILS_ENV=production
ENV RAILS_ENV=${RAILS_ENV}

ARG RAILS_SERVE_STATIC_FILES=true
ENV RAILS_SERVE_STATIC_FILES=${RAILS_SERVE_STATIC_FILES}

ARG NODE_OPTIONS="--max-old-space-size=4096 --openssl-legacy-provider"
ENV NODE_OPTIONS=${NODE_OPTIONS}

ENV BUNDLE_PATH="/gems"

# ──────────── Dependencias de sistema (Ruby + build) ────────────
RUN apk update && apk add --no-cache \
  build-base \
  git \
  postgresql-dev postgresql-client \
  tzdata \
  openssl \
  vips \
  linux-headers \
  ruby-dev \
  libc6-compat \
  curl tar xz \
  && gem install bundler -v "${BUNDLER_VERSION}"

# ──────────── Node 23 .x y pnpm 10 .x ────────────
ARG NODE_VERSION=23.7.0
RUN curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
      | tar -xJ -C /usr/local --strip-components=1 \
  && corepack enable \
  && corepack prepare pnpm@10 --activate

ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

WORKDIR /app

# ──────────── Ruby gems ────────────
COPY Gemfile Gemfile.lock ./
RUN bundle lock --add-platform x86_64-linux-musl \
  && bundle config set without 'development test' \
  && bundle install -j4

# ──────────── Dependencias JS ────────────
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# ──────────── Copiar el resto de la app ────────────
COPY . /app

# Logs dir por si RAILS_LOG_TO_STDOUT=false
RUN mkdir -p /app/log

# ──────────── Pre-compilación de assets ────────────
RUN SECRET_KEY_BASE=precompile_placeholder RAILS_LOG_TO_STDOUT=enabled \
    bundle exec rake assets:precompile \
 && rm -rf spec node_modules tmp/cache

# Guardar el SHA del commit (opcional)
RUN git rev-parse HEAD > /app/.git_sha

# ──────────── Limpieza ────────────
RUN rm -rf /gems/ruby/3.3.0/cache/*.gem \
 && find /gems/ruby/3.3.0/gems/ \( -name "*.c" -o -name "*.o" \) -delete \
 && rm -rf .git \
 && rm .gitignore

###################################################################
# 2. Etapa final (imagen ligera para producción)
###################################################################
FROM ruby:3.3.3-alpine3.19

# ──────────── Variables ────────────
ARG BUNDLE_WITHOUT="development:test"
ENV BUNDLE_WITHOUT=${BUNDLE_WITHOUT}
ENV BUNDLER_VERSION=2.5.11

ARG RAILS_ENV=production
ENV RAILS_ENV=${RAILS_ENV}
ENV BUNDLE_PATH="/gems"

ENV RAILS_SERVE_STATIC_FILES=true
ENV EXECJS_RUNTIME="Disabled"

# ──────────── Dependencias mínimas runtime ────────────
RUN apk update && apk add --no-cache \
  tzdata \
  postgresql-client \
  vips \
  openssl \
  libc6-compat

# ──────────── Copiar artefactos build ────────────
COPY --from=pre-builder /gems/ /gems/
COPY --from=pre-builder /app /app
COPY --from=pre-builder /app/.git_sha /app/.git_sha      # opcional

WORKDIR /app
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
