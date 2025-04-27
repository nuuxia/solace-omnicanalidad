###################################################################
# Stage 0 – Node 23 + pnpm 10 (musl)
###################################################################
FROM node:23-alpine AS node-deps
RUN corepack enable && corepack prepare pnpm@10 --activate
WORKDIR /deps
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

###################################################################
# Stage 1 – pre-builder Ruby
###################################################################
FROM ruby:3.3.3-alpine3.19 AS pre-builder
ARG BUNDLER_VERSION=2.5.11
ENV BUNDLE_PATH=/gems \
    RAILS_ENV=production \
    RAILS_SERVE_STATIC_FILES=true \
    NODE_OPTIONS="--max-old-space-size=4096 --openssl-legacy-provider"

RUN apk update && apk add --no-cache \
      build-base git \
      postgresql-dev postgresql-client \
      tzdata openssl vips linux-headers \
      ruby-dev libc6-compat

# Copiamos Node (binarios + pnpm store) desde el stage anterior
COPY --from=node-deps /usr/local /usr/local
ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

# ── Bundler ───────────────────────────────────────────────────────
WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v "$BUNDLER_VERSION" && \
    bundle lock --add-platform x86_64-linux-musl && \
    bundle config set without 'development test' && \
    bundle install -j4

# ── node_modules ya vienen del stage Node; copiamos resto app ─────
COPY . .
RUN mkdir -p log && \
    SECRET_KEY_BASE=dummy bundle exec rake assets:precompile && \
    rm -rf spec node_modules tmp/cache

###################################################################
# Stage 2 – final
###################################################################
FROM ruby:3.3.3-alpine3.19
ENV BUNDLE_PATH=/gems \
    RAILS_ENV=production \
    RAILS_SERVE_STATIC_FILES=true \
    EXECJS_RUNTIME=Disabled

RUN apk update && apk add --no-cache \
      tzdata postgresql-client vips openssl libc6-compat

COPY --from=pre-builder /gems/ /gems/
COPY --from=pre-builder /app /app
WORKDIR /app
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
