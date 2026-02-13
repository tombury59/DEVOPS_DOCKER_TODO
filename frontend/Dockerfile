# Stage 1: Build
FROM node:24-alpine AS builder
WORKDIR /app

# Copier les fichiers de dépendances
COPY package*.json ./

# Installer les dépendances
RUN npm ci

# Copier le code source
COPY . .

# Build l'application React
RUN npm run build

# Stage 2: Production avec Nginx
FROM nginx:alpine
WORKDIR /usr/share/nginx/html

# Supprimer les fichiers par défaut de nginx
RUN rm -rf ./*

# Copier les fichiers buildés depuis le stage builder
COPY --from=builder /app/dist .

# Copier la configuration nginx personnalisée
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Exposer le port 80
EXPOSE 80

# Démarrer nginx
CMD ["nginx", "-g", "daemon off;"]
