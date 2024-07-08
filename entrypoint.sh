#!/bin/bash

ENV_LOCAL_PATH=/app/.env.local

# Check if DOTENV_LOCAL is not empty and create .env.local file if necessary
if [ -z "${DOTENV_LOCAL}" ]; then
    if [ ! -f "${ENV_LOCAL_PATH}" ]; then
        echo "DOTENV_LOCAL was not found in the ENV variables and .env.local is not set using a bind volume. Make sure to set environment variables properly."
    fi
else
    echo "DOTENV_LOCAL was found in the ENV variables. Creating .env.local file."
    echo "${DOTENV_LOCAL}" > "${ENV_LOCAL_PATH}"
fi

# Start local MongoDB instance if INCLUDE_DB is true    
if [ "${INCLUDE_DB}" = "true" ]; then
    echo "Starting local MongoDB instance"
    nohup mongod &
fi

# Export public version from package.json
export PUBLIC_VERSION=$(node -p "require('./package.json').version")

# Run dotenv to load environment variables from .env and start the Node.js server
dotenv -e /app/.env -c -- node /app/build/index.js -- --host 0.0.0.0 --port 3000
