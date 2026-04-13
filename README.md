# Gestionnaire de tâches - Projet DevOps / Docker

C'est une application de gestion de tâches composée de plusieurs briques :

- un **frontend React** (Vite)
- un **service tasks-service** (API Node/Express + PostgreSQL) pour gérer les tâches
- un **service stats-service** pour calculer des statistiques sur les tâches
- un **reverse-proxy Nginx** devant tout ça
- des fichiers **Docker Compose** (dev / prod) et des manifests **Kubernetes**

L’objectif du projet est de mettre en place une vraie petite chaîne "Dev → Build → Registry → Deploy" avec un **registry Docker local** et un **Taskfile** qui orchestre tout.

---

## 1. Pipeline avec `Taskfile.yml`

À la racine du projet, on utilise [`Task`](https://taskfile.dev) pour automatiser les étapes classiques d’une CI.

La commande principale est :

```powershell
# Depuis la racine du projet
task ci
```

Cette tâche `ci` enchaîne automatiquement :

1. **install** : installe les dépendances npm pour les 3 projets :
   - `tasks-service`
   - `stats-service`
   - `frontend`
2. **lint:all** : lance le lint sur :
   - `tasks-service`
   - `stats-service`
   - `frontend`
3. **test** : lance les tests unitaires (Vitest) sur :
   - `tasks-service`
   - `stats-service`
   - tente aussi `npm test` sur le frontend (si le script n’existe pas, l’erreur est gérée dans la CI du projet)
4. **build:services** : build TypeScript/React (`npm run build`) pour :
   - `tasks-service`
   - `stats-service`
   - `frontend`
5. **build** : build des images Docker via `docker compose build`
6. **push:all** : push des images générées vers le **registry local** (voir section suivante)
7. **deploy:docker** : déploiement de la pile "prod" locale via `docker-compose.prod.yml`

En pratique, pour corriger le projet, on peut se contenter de :

```powershell
cd GROS-PROJET
task ci
```

et suivre les logs.

---

## 2. Registry Docker local (localhost:5000)

Comme vu en cours, on utilise un **registry Docker local** pour simuler un registry distant (Docker Hub / GitLab / etc.) mais en local :

- il tourne sur `localhost:5000`
- il est déclaré comme service `registry` dans `docker-compose.yml`
- les images du projet y sont poussées avec le tag `latest`

### 2.1. Lancer et vérifier le registry

Toujours depuis la racine du projet :

```powershell
# Démarrer le registry (ou le créer s’il n’existe pas)
task registry-start

# Vérifier que le registry répond bien
task registry-status

# Lister les images présentes dans le registry
task registry-verify
```

Le registry expose une API compatible Docker Registry :

- Ping : `http://localhost:5000/v2/`
- Catalogue des images : `http://localhost:5000/v2/_catalog`

### 2.2. Push des images du projet

La tâche `task ci` s’occupe déjà de **builder et pusher** les images. Si on veut le faire à la main :

```powershell
# Build des images Docker
task build

# Push de toutes les images vers le registry local
task push:all
```

Les images sont poussées sous la forme :

- `localhost:5000/tasks-service:latest`
- `localhost:5000/stats-service:latest`
- `localhost:5000/frontend:latest`

On peut ensuite vérifier ce qui est stocké dans le registry :

```powershell
# Liste des repositories
task registry:list
```

---

## 3. Les différents Docker Compose

À la racine, on a plusieurs fichiers compose qui couvrent les différents scénarios :

- `docker-compose.yml` : stack "classique" + registry local (utilisée pour le TP)
- `docker-compose.dev.yml` : environnement de **développement**
- `docker-compose.prod.yml` : environnement "**production locale**" qui tire les images depuis le registry local

### 3.1. `docker-compose.yml` – stack + registry

Ce fichier décrit :

- `tasks-service` (API Node + Postgres)
- `stats-service`
- `frontend`
- `db` (PostgreSQL)
- `nginx` (reverse proxy)
- `adminer` (interface web pour la DB)
- `registry` (registry Docker local sur `localhost:5000`)

Usage typique :

```powershell
# Lancer la stack "de base" + registry
docker compose up -d

# Arrêter
docker compose down
```

⚠️ Attention au **port 80** :

- Nginx est mappé sur le port 80 de la machine.
- Si un autre service écoute déjà sur 80 (IIS, WSL, un autre nginx...), vous aurez une erreur du type :

> Bind for 0.0.0.0:80 failed: port is already allocated

Dans ce cas, deux options :

1. Stopper le service qui utilise déjà le port 80
2. Modifier le mapping de port dans `docker-compose.yml` / config `nginx` (par exemple `8080:80`)

### 3.2. `docker-compose.dev.yml` – environnement DEV

Ce compose sert à bosser **en local, en mode dev**. L’idée est :

- d’avoir la base de données et les services applicatifs qui tournent dans Docker
- d’exposer des ports pratiques pour brancher un IDE / un client HTTP
- de pouvoir relancer rapidement le stack pendant le développement

Lancement :

```powershell
# Depuis la racine du projet
docker compose -f docker-compose.dev.yml up --build
```

Avant ça, on peut créer un petit fichier `.env.dev` à la racine avec les variables qu’on veut sur la DB, par exemple :

```env
POSTGRES_DB=tasks
POSTGRES_USER=tasks
POSTGRES_PASSWORD=tasks
```

Pense aussi à vérifier que les ports utilisés dans `docker-compose.dev.yml` ne sont pas déjà pris.

### 3.3. `docker-compose.prod.yml` – "prod" locale avec registry

Ce fichier est utilisé pour simuler un déploiement de production **à partir d’images présentes dans le registry local**.

Il est appelé par la tâche :

```powershell
# Pipeline complète
task ci

# ou juste le déploiement
task deploy:docker
```

Derrière, la commande ressemble à :

```powershell
DOCKER_REGISTRY=localhost:5000 DOCKER_TAG=latest docker compose -f docker-compose.prod.yml up -d --remove-orphans
```

Les services sont déclarés avec des images du type :

- `${DOCKER_REGISTRY}/frontend:${DOCKER_TAG}`
- `${DOCKER_REGISTRY}/tasks-service:${DOCKER_TAG}`
- `${DOCKER_REGISTRY}/stats-service:${DOCKER_TAG}`

Pour que ça marche, il faut donc :

1. Avoir le registry local qui tourne :
   ```powershell
   task registry-start
   ```
2. Avoir poussé les images dans le registry :
   ```powershell
   task push:all
   ```
   (ou simplement `task ci` qui fait tout)

Le même problème de port 80 peut se produire ici (service `nginx` en prod). Si le port est déjà pris, adapter le mapping ou libérer le port.

---

## 4. Accéder aux services

En fonction du mode (Compose ou Kubernetes), les ports peuvent varier, mais en "prod" locale (K8s avec NodePort par exemple), on peut retrouver quelque chose comme :

- Frontend : `http://localhost:30082/`
- Tasks API : `http://localhost:30080/api/tasks`
- Stats API : `http://localhost:30081/api/stats/summary`

Quelques commandes utiles :

```bash
# Vérifier que le frontend répond
curl http://localhost:30082/

# Récupérer la liste des tâches
curl http://localhost:30080/api/tasks

# Récupérer un résumé des stats
curl http://localhost:30081/api/stats/summary
```

Créer une tâche en ligne de commande :

```bash
curl -v -H "Content-Type: application/json" \
  -d '{"title":"Ma tâche","description":"depuis curl"}' \
  http://localhost:30080/api/tasks
```

---

## 5. Kubernetes (optionnel)

Le dossier `k8s/` contient les manifests pour déployer les services dans un cluster Kubernetes local (type kind / k3d / minikube) :

- `tasks-service-*`
- `stats-service-*`
- `frontend-*`

On retrouve :

- des `Deployment`
- des `Service` (type NodePort)
- des `ConfigMap` / `Secret` pour la configuration de la DB

Déploiement rapide :

```bash
# Depuis la racine
task deploy:k8s

# Pour tout supprimer
task deploy:k8s:delete
```

---

## 6. Récap rapide

- **Dev local** :
  ```powershell
  docker compose -f docker-compose.dev.yml up --build
  ```
- **Registry local** :
  ```powershell
  task registry-start
  task registry-status
  ```
- **Pipeline complète (CI locale)** :
  ```powershell
  task ci
  ```
- **Déploiement Docker prod locale** :
  ```powershell
  task deploy:docker
  ```
- **Déploiement Kubernetes** :
  ```bash
  task deploy:k8s
  ```

Ce README vise à expliquer rapidement comment lancer le projet comme si on'était en TD/TP : d’abord en local, puis en mode "petit environnement de prod" avec un registry Docker local et une pipeline qui automatise les étapes importantes.
