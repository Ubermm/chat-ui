# Read the doc: https://huggingface.co/docs/hub/spaces-sdks-docker
# You will also find guides on how best to write your Dockerfile

ARG INCLUDE_DB=false

# Stage that installs the production dependencies
FROM node:20 AS builder-production

WORKDIR /app

COPY --link --chown=1000 package-lock.json package.json ./
RUN --mount=type=cache,target=/app/.npm \
    npm set cache /app/.npm && \
    npm ci --omit=dev

# Intermediate stage for building the application
FROM builder-production AS builder

ARG APP_BASE=
ARG PUBLIC_APP_COLOR=black
ENV BODY_SIZE_LIMIT=15728640

RUN --mount=type=cache,target=/app/.npm \
    npm set cache /app/.npm && \
    npm ci

COPY --link --chown=1000 . .

RUN npm run build

# MongoDB stage
FROM mongo:latest AS mongo

# Image used if INCLUDE_DB is false
FROM node:20-slim AS local_db_false

# Image used if INCLUDE_DB is true
FROM node:20-slim AS local_db_true

RUN apt-get update \
    && apt-get install -y gnupg curl \
    && rm -rf /var/lib/apt/lists/*

# Copy MongoDB binaries from mongo stage
COPY --from=mongo /usr/bin/mongo* /usr/bin/

ENV MONGODB_URL=mongodb://localhost:27017
RUN mkdir -p /data/db \
    && chown -R 1000:1000 /data/db

# Final image stage
FROM local_db_${INCLUDE_DB} AS final

ARG INCLUDE_DB=false
ENV INCLUDE_DB=${INCLUDE_DB}

ARG APP_BASE=
ARG PUBLIC_APP_COLOR=black
ENV BODY_SIZE_LIMIT=15728640

RUN npm install -g dotenv-cli

RUN userdel -r node \
    && useradd -m -u 1000 user

USER user

ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH

WORKDIR /app

RUN sed -i 's/\r$//' /app/entrypoint.sh  # Fix line endings issue

RUN touch /app/.env.local
RUN dos2unix entrpoint.sh entrypoint.sh
COPY --chown=1000 package.json /app/package.json
COPY --chown=1000 .env /app/.env
COPY --chown=1000 entrypoint.sh /app/entrypoint.sh
COPY --chown=1000 gcp-*.json /app/

COPY --from=builder --chown=1000 /app/build /app/build
COPY --from=builder --chown=1000 /app/node_modules /app/node_modules

RUN npx playwright install

USER root
RUN npx playwright install-deps

USER user

RUN chmod +x /app/entrypoint.sh

CMD ["/bin/bash", "-c", "/app/entrypoint.sh"]
