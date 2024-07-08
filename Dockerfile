# syntax=docker/dockerfile:experimental

# Stage that installs the production dependencies
FROM node:20 AS builder-production

WORKDIR /app

COPY package-lock.json package.json ./
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

COPY . .

RUN npm run build

# MongoDB stage
FROM mongo:latest AS mongo

# Final image stage
FROM node:20-slim AS final

ARG INCLUDE_DB=false
ENV INCLUDE_DB=${INCLUDE_DB}

RUN npm install -g dotenv-cli

RUN userdel -r node \
    && useradd -m -u 1000 user

USER user

ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH

WORKDIR /app

RUN sed -i 's/\r$//' /app/entrypoint.sh  # Fix line endings issue

RUN touch /app/.env.local

COPY package.json /app/package.json
COPY .env /app/.env
COPY entrypoint.sh /app/entrypoint.sh
COPY gcp-*.json /app/

COPY --from=builder /app/build /app/build
COPY --from=builder /app/node_modules /app/node_modules

RUN npx playwright install

USER root
RUN npx playwright install-deps

USER user

RUN chmod +x /app/entrypoint.sh

CMD ["/bin/bash", "-c", "/app/entrypoint.sh"]
