# --- Stage 1: Base ---
FROM node:24-alpine AS base
WORKDIR /app
COPY package*.json ./
RUN npm install

# --- Stage 2: Development ---
FROM base AS dev
COPY . .
CMD ["npm", "run", "dev"]

# --- Intermediate Stage: Builder ---
FROM base AS builder
COPY . .
RUN npm run build

# --- Stage 3: Production ---
FROM node:24-alpine AS prod
WORKDIR /app
ENV NODE_ENV=production

COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY --from=builder /app/dist ./dist

USER node
EXPOSE 3002
CMD ["node", "dist/server.js"]
