# 1) Node stage: install Node.js and PNPM
FROM node:23-alpine AS node

# Install specific PNPM version globally
ARG PNPM_VERSION="10.2.0"
RUN npm install -g pnpm@${PNPM_VERSION} \
  && pnpm --version

# 2) Pre-builder stage: install gems, JS deps, and compile assets
FROM ruby:3.4.4-alpine3.21 AS pre-builder

# Build arguments and environment variables
ARG BUNDLE_WITHOUT="development:test"
ARG RAILS_ENV="production"
ARG BUNDLER_VERSION="2.5.11"
ENV BUNDLE_WITHOUT=${BUNDLE_WITHOUT} \
    RAILS_ENV=${RAILS_ENV} \
    BUNDLER_VERSION=${BUNDLER_VERSION} \
    BUNDLE_PATH="/gems" \
    NODE_OPTIONS="--max-old-space-size=4096 --openssl-legacy-provider" \
    PNPM_HOME="/root/.local/share/pnpm" \
    PATH="$PNPM_HOME:$PATH"

WORKDIR /app

# Install build dependencies (including those needed by ffi and other gems)
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
  && gem install bundler -v ${BUNDLER_VERSION}

# Copy Gemfile and install Ruby gems
COPY Gemfile Gemfile.lock ./
RUN bundle config set force_ruby_platform true \
  && bundle install --jobs 4 --retry 3

# Copy PNPM binaries from the Node stage
COPY --from=node /usr/local /usr/local

# Install JS dependencies and precompile assets
COPY package.json pnpm-lock.yaml ./
RUN pnpm install \
  && SECRET_KEY_BASE=precompile_placeholder RAILS_LOG_TO_STDOUT=enabled \
     bundle exec rake assets:precompile \
  && rm -rf node_modules tmp/cache

# Copy the rest of the application code
COPY . .

# Clean up git metadata and compiled gem artifacts
RUN mkdir -p log \
  && git rev-parse HEAD > .git_sha \
  && rm -rf .git .gitignore \
  && rm -rf /gems/ruby/*/cache/*.gem \
  && find /gems/ruby/*/gems -type f \( -name "*.c" -o -name "*.o" \) -delete

# 3) Final stage: minimal runtime image with gems and app
FROM ruby:3.4.4-alpine3.21

# Arguments and environment for the final image
ARG BUNDLE_WITHOUT="development:test"
ARG BUNDLER_VERSION="2.5.11"
ENV BUNDLE_WITHOUT=${BUNDLE_WITHOUT} \
    BUNDLER_VERSION=${BUNDLER_VERSION} \
    RAILS_ENV="production" \
    BUNDLE_PATH="/gems" \
    RAILS_SERVE_STATIC_FILES=true \
    EXECJS_RUNTIME="Disabled"

WORKDIR /app

# Install runtime dependencies
RUN apk update && apk add --no-cache \
    git \
    imagemagick \
    postgresql-client \
    tzdata \
    vips \
    openssl \
  && gem install bundler -v ${BUNDLER_VERSION}

# Copy the bundled gems and application from pre-builder
COPY --from=pre-builder /gems /gems
COPY --from=pre-builder /app /app

# Expose port and set default command
EXPOSE 3000
CMD ["bundle", "exec", "rails", "s", "-b", "0.0.0.0"]
