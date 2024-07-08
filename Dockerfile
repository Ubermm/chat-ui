RUN ls -l /app/entrypoint.sh  # Check current permissions
RUN id  # Print user and group information

# Final image stage
FROM local_db_${INCLUDE_DB} AS final

ARG APP_BASE=
ARG PUBLIC_APP_COLOR=black
ENV BODY_SIZE_LIMIT=15728640

RUN npm install -g dotenv-cli

RUN userdel -r node \
    && useradd -m -u 1000 user

USER root  # Switch to root user temporarily

ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH

WORKDIR /app

# Convert entrypoint.sh to Unix format if needed
RUN dos2unix /app/entrypoint.sh > /dev/null 2>&1 || true

RUN touch /app/.env.local
COPY package.json /app/package.json
COPY .env /app/.env
COPY entrypoint.sh /app/entrypoint.sh

# Adjust permissions with elevated privileges
RUN chmod +x /app/entrypoint.sh

# Switch back to non-root user
USER user

COPY gcp-*.json /app/

COPY --from=builder /app/build /app/build
COPY --from=builder /app/node_modules /app/node_modules

RUN npx playwright install

RUN npx playwright install-deps

CMD ["/bin/bash", "-c", "/app/entrypoint.sh"]
