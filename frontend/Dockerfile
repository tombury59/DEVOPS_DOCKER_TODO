# --- Stage 1: Base ---
FROM node:24-alpine AS base
WORKDIR /app
# Copier les fichiers de dépendances
COPY package*.json ./
RUN npm ci --legacy-peer-deps

# --- Stage 2: Development ---
FROM base AS dev
COPY . .
EXPOSE 80
# Override vite port to 80 so docker-compose mapping works
CMD ["npm", "run", "dev", "--", "--port", "80"]

# --- Intermediate Stage: Builder ---
FROM base AS builder
COPY . .
RUN npm run build

# --- Stage 3: Production avec Nginx ---
FROM nginx:alpine
WORKDIR /usr/share/nginx/html
# Supprimer les fichiers par défaut de nginx
RUN rm -rf ./*
# Copier les fichiers buildés
COPY --from=builder /app/dist .
# Copier la configuration nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
