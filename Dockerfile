# AniFlow API - Northflank production image
# Build with: docker build -t aniflow-api .

FROM node:22-bookworm-slim AS deps
WORKDIR /app

# Lockfile is committed in the repository; npm ci keeps installs reproducible.
COPY package.json package-lock.json ./
RUN npm ci

FROM node:22-bookworm-slim AS builder
WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Build needs devDependencies such as TypeScript, Tailwind CSS and PostCSS.
RUN npm run build

# Keep only runtime dependencies in the final image.
RUN npm prune --omit=dev

FROM node:22-bookworm-slim AS runner
WORKDIR /app

ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    HOSTNAME=0.0.0.0 \
    PORT=3000

# The public directory is used for the app's static assets.
COPY --from=builder --chown=node:node /app/public ./public
COPY --from=builder --chown=node:node /app/.next ./.next
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/package.json ./package.json
COPY --from=builder --chown=node:node /app/next.config.mjs ./next.config.mjs

USER node
EXPOSE 3000

# Respect Northflank's PORT if one is explicitly configured; otherwise use 3000.
CMD ["sh", "-c", "npm run start -- -H 0.0.0.0 -p ${PORT:-3000}"]
