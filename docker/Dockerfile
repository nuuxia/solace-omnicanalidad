###################################################################
# 1. Etapa de pre-build (compila gems y JS assets)
###################################################################
FROM ruby:3.3.3-alpine3.19 AS pre-builder

# Variables de entorno y argumentos de build
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

# Instalar dependencias requeridas para compilar gems y frontend
RUN apk update && apk add --no-cache \
  build-base \
  git \
  postgresql-dev \
  postgresql-client \
  nodejs=20.15.1-r0 \
  npm \
  tzdata \
  openssl \
  vips \
  linux-headers \
  ruby-dev \
  libc6-compat \
  && gem install bundler -v "${BUNDLER_VERSION}"

# Instalar pnpm versión 9.x (la versión compatible)
RUN npm install -g pnpm@9

ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

WORKDIR /app

# Copiar Gemfile y Gemfile.lock antes para usar la caché de Bundler
COPY Gemfile Gemfile.lock ./

# AÑADIMOS la plataforma Alpine (musl) al lockfile para evitar errores:
RUN bundle lock --add-platform x86_64-linux-musl

# Instalar las gemas
RUN bundle config set without 'development test' && bundle install -j4

# Copiar package.json y pnpm-lock.yaml
COPY package.json pnpm-lock.yaml ./
RUN pnpm install

# Copiar el resto de la app
COPY . /app

# Crear directorio de logs (por si RAILS_LOG_TO_STDOUT está en false)
RUN mkdir -p /app/log

# Precompilar assets en producción
RUN SECRET_KEY_BASE=precompile_placeholder RAILS_LOG_TO_STDOUT=enabled \
      bundle exec rake assets:precompile && \
      rm -rf spec node_modules tmp/cache

# Generar archivo .git_sha con el commit actual (opcional)
RUN git rev-parse HEAD > /app/.git_sha

# Limpiar archivos innecesarios
RUN rm -rf /gems/ruby/3.3.0/cache/*.gem \
  && find /gems/ruby/3.3.0/gems/ \( -name "*.c" -o -name "*.o" \) -delete \
  && rm -rf .git \
  && rm .gitignore

###################################################################
# 2. Etapa final (imagen limpia para producción)
###################################################################
FROM ruby:3.3.3-alpine3.19

ARG BUNDLE_WITHOUT="development:test"
ENV BUNDLE_WITHOUT=${BUNDLE_WITHOUT}
ENV BUNDLER_VERSION=2.5.11

ARG RAILS_ENV=production
ENV RAILS_ENV=${RAILS_ENV}
ENV BUNDLE_PATH="/gems"

# Permite servir static files con Rails
ENV RAILS_SERVE_STATIC_FILES=true
# Desactiva ExecJS
ENV EXECJS_RUNTIME="Disabled"

# Instalar dependencias mínimas para runtime
RUN apk update && apk add --no-cache \
  tzdata \
  postgresql-client \
  vips \
  openssl \
  libc6-compat

# Copiar las gems y el código de la etapa anterior
COPY --from=pre-builder /gems/ /gems/
COPY --from=pre-builder /app /app

WORKDIR /app

# (Opcional) confirmar que el .git_sha se copió
COPY --from=pre-builder /app/.git_sha /app/.git_sha

# Exponer puerto para Rails
EXPOSE 3000
