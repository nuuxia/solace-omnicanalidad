###################################################################
# 1. Etapa de pre-build (instala dependencias y compila assets)
###################################################################
FROM ruby:3.3.3-alpine3.19 AS pre-builder

# Definir argumentos y variables de entorno
ARG BUNDLE_WITHOUT="test"
ARG BUNDLER_VERSION=2.5.11
ARG RAILS_ENV=development

ENV BUNDLE_WITHOUT=${BUNDLE_WITHOUT}
ENV BUNDLER_VERSION=${BUNDLER_VERSION}
ENV RAILS_ENV=${RAILS_ENV}
ENV BUNDLE_PATH="/gems"
ENV DOCKERIZED=true
ENV PATH="/app/bin:$PATH"

# Instalar dependencias requeridas
RUN apk update && apk add --no-cache \
  build-base \
  git \
  postgresql-dev \
  postgresql-client \
  nodejs \
  npm \
  tzdata \
  openssl \
  vips \
  && gem install bundler -v "${BUNDLER_VERSION}"

# Instalar `pnpm`
RUN npm install -g pnpm@9

# Configurar `pnpm`
ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

# Configurar directorio de trabajo
WORKDIR /app

# 🔥 **Arreglar el error de "dubious ownership"**
RUN git config --global --add safe.directory /app

# Copiar y preparar Ruby gems
COPY Gemfile Gemfile.lock ./
RUN bundle install -j4

# Copiar archivos de frontend y preparar Node.js
COPY package.json pnpm-lock.yaml ./

# Instalar módulos con `pnpm`
RUN pnpm install --shamefully-hoist

# Copiar toda la app
COPY . /app

# Limpiar caché y permisos
RUN rm -rf /gems/ruby/3.3.0/cache/*.gem \
  && find /gems/ruby/3.3.0/gems/ \( -name "*.c" -o -name "*.o" \) -delete

RUN chown -R nobody:nobody /app
USER nobody

# Crear directorio de logs
RUN mkdir -p /app/log

###################################################################
# 2. Etapa final (imagen optimizada)
###################################################################
FROM ruby:3.3.3-alpine3.19

# Variables de entorno
ARG BUNDLER_VERSION=2.5.11
ARG RAILS_ENV=development

ENV BUNDLE_WITHOUT="test"
ENV BUNDLER_VERSION=${BUNDLER_VERSION}
ENV RAILS_ENV=${RAILS_ENV}
ENV BUNDLE_PATH="/gems"
ENV EXECJS_RUNTIME="Disabled"

# Instalar dependencias mínimas
RUN apk update && apk add --no-cache \
  tzdata \
  postgresql-client \
  vips \
  openssl \
  git \
  nodejs \
  npm

# Instalar `pnpm`
RUN npm install -g pnpm@9

# Copiar gems y código
COPY --from=pre-builder /gems/ /gems/
COPY --from=pre-builder /app /app

# Configurar directorio de trabajo
WORKDIR /app

# Asegurar que `node_modules` están disponibles
COPY --from=pre-builder /app/node_modules /app/node_modules

# Configurar `pnpm`
ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

# 🔥 **Arreglar "dubious ownership" en el contenedor final**
RUN git config --global --add safe.directory /app

# Exponer el puerto de Rails
EXPOSE 3000

CMD ["sh", "-c", "rm -f /app/tmp/pids/server.pid && bundle exec rails server -b 0.0.0.0"]
