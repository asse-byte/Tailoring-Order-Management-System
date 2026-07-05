FROM node:22-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY src ./src
COPY scripts ./scripts
COPY migrations ./migrations

ENV NODE_ENV=production
EXPOSE 3000

# Migrations run on every boot (idempotent), then the API starts.
CMD ["sh", "-c", "node scripts/migrate.js && node src/server.js"]
