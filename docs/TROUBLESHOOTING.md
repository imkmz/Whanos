# Troubleshooting & Setup Guide

Guide pour démarrer Jenkins et résoudre les problèmes courants.

## Démarrage Initial

### 1. Build Jenkins depuis la racine du projet

⚠️ **IMPORTANT** : Le build doit se faire depuis la **racine** du projet, pas depuis le dossier `jenkins/` !

```bash
# ✅ CORRECT - depuis la racine
cd /path/to/G-DOP-500-STG-5-1-whanos-6
docker build -t whanos-jenkins -f jenkins/Dockerfile .

# ❌ INCORRECT - ne fonctionne pas
cd jenkins
docker build -t whanos-jenkins .
```

**Pourquoi ?** Le Dockerfile copie des fichiers depuis `images/`, `kubernetes/`, `jenkins/` qui sont relatifs à la racine du projet.

### 2. Démarrer Jenkins

```bash
cd /path/to/G-DOP-500-STG-5-1-whanos-6
docker compose up -d jenkins
```

Attendre 30-60 secondes que Jenkins démarre.

### 3. Vérifier que Jenkins est prêt

```bash
docker logs whanos-jenkins | grep "fully up"
```

Tu devrais voir : `Jenkins is fully up and running`

### 4. Accéder à Jenkins

Ouvre ton navigateur : **http://localhost:8080**

**Credentials :**
- Username: `admin`
- Password: `admin`

---

## Problème 1 : Permission Docker Denied

### Symptôme

Les jobs échouent avec :
```
ERROR: permission denied while trying to connect to the Docker daemon socket
```

### Solution

À **chaque démarrage** de Jenkins, exécute cette commande :

```bash
docker exec -u root whanos-jenkins chmod 666 /var/run/docker.sock
```

### Vérification

```bash
docker exec whanos-jenkins docker version
```

Tu devrais voir la version du client et du serveur Docker.

### Pourquoi ce problème ?

Jenkins tourne avec l'utilisateur `jenkins` qui n'a pas les permissions par défaut pour accéder au socket Docker de l'hôte.

---

## Problème 2 : Script Not Yet Approved

### Symptôme

Le job `link-project` échoue avec :
```
ERROR: script not yet approved for use
Finished: FAILURE
```

### Solution

1. Va sur Jenkins : **http://localhost:8080**
2. Clique sur **"Manage Jenkins"** (menu gauche)
3. Cherche et clique sur **"In-process Script Approval"**
4. Tu verras une ou plusieurs signatures en attente, par exemple :
   ```
   method hudson.model.ItemGroup getItem java.lang.String
   ```
5. Clique sur **"Approve"** pour chaque signature
6. Retourne au job et relance-le

### Pourquoi ce problème ?

Jenkins bloque l'exécution de scripts Groovy non approuvés pour des raisons de sécurité. Il faut approuver manuellement les méthodes utilisées.

---

## Problème 3 : Build Errors "Cannot connect to Docker daemon"

### Symptôme

Les jobs `whanos-c`, `whanos-java`, etc. échouent tous immédiatement.

### Vérification

```bash
# Vérifier que Jenkins peut accéder à Docker
docker exec whanos-jenkins docker info

# Vérifier les permissions du socket
ls -la /var/run/docker.sock
```

### Solution

Voir **Problème 1** ci-dessus.

---

## Problème 4 : Jobs ne se déclenchent pas automatiquement

### Symptôme

Le job "Build all base images" se termine en SUCCESS mais ne lance pas les 5 sous-jobs.

### Vérification

Vérifie que le plugin `parameterized-trigger` est installé :

1. Va sur **Manage Jenkins** → **Plugins**
2. Cherche "Parameterized Trigger Plugin"
3. S'il n'est pas installé, installe-le

### Solution de contournement

Lance les jobs manuellement :
- `Whanos base images` → `whanos-c` → Build Now
- `Whanos base images` → `whanos-java` → Build Now
- etc.

---

## Problème 5 : Espace disque insuffisant

### Symptôme

```
ERROR: no space left on device
```

### Solution

Nettoie les images et containers Docker :

```bash
# Voir l'espace utilisé
docker system df

# Nettoyer les images non utilisées
docker image prune -a

# Nettoyer tout (attention : supprime tout sauf les volumes)
docker system prune -a
```

---

## Workflow de Test Complet

### 1. Construire les images de base

**Option A : Via Jenkins (recommandé)**

1. Va sur Jenkins
2. Ouvre le dossier `Whanos base images`
3. Clique sur `Build all base images`
4. Clique "Build Now"
5. Attends que tous les 5 jobs se terminent (5-10 minutes)

**Option B : Manuellement**

```bash
cd /path/to/G-DOP-500-STG-5-1-whanos-6

# Build toutes les images
docker build -t whanos-befunge -f images/befunge/Dockerfile.base images/befunge
docker build -t whanos-c -f images/c/Dockerfile.base images/c
docker build -t whanos-java -f images/java/Dockerfile.base images/java
docker build -t whanos-javascript -f images/javascript/Dockerfile.base images/javascript
docker build -t whanos-python -f images/python/Dockerfile.base images/python

# Vérifier
docker images | grep whanos
```

### 2. Créer un projet avec link-project

**Prérequis :** Un repository GitHub avec la structure correcte :

```
mon-app/                  ← racine du repo
├── package.json          ← À LA RACINE
├── app/                  ← À LA RACINE
│   └── index.js
└── whanos.yml           ← optionnel
```

⚠️ **Erreur courante** : Avoir un sous-dossier `test-javascript-app/` au lieu d'avoir les fichiers directement à la racine.

**Étapes :**

1. Va sur Jenkins : http://localhost:8080
2. Clique sur `link-project` (à la racine)
3. Clique "Build with Parameters"
4. Entre :
   - **DISPLAY_NAME** : `mon-projet` (nom du job qui sera créé)
   - **GIT_URL** : `https://github.com/username/mon-repo.git`
5. Clique "Build"

**Si erreur "script not approved"** : Voir Problème 2 ci-dessus

### 3. Vérifier le projet créé

1. Va dans le dossier `Projects`
2. Tu devrais voir ton nouveau job `mon-projet`
3. Clique dessus
4. Le job devrait :
   - Poll le repo Git toutes les minutes (`* * * * *`)
   - Détecter le langage automatiquement
   - Builder une image Docker

### 4. Tester le build automatique

1. Fais un commit dans ton repo GitHub
2. Attends 1 minute maximum
3. Le job devrait se lancer automatiquement
4. Vérifie la Console Output

---

## Structure des Jobs Jenkins

Après démarrage, tu devrais voir :

```
Jenkins Root
├── Whanos base images/          [Folder]
│   ├── Build all base images    [Job]
│   ├── whanos-befunge           [Job]
│   ├── whanos-c                 [Job]
│   ├── whanos-java              [Job]
│   ├── whanos-javascript        [Job]
│   └── whanos-python            [Job]
├── Projects/                     [Folder - vide au début]
└── link-project                  [Job]
```

Après avoir utilisé `link-project`, le dossier `Projects/` contiendra les jobs des projets liés.

---

## Commandes Utiles

### Redémarrer Jenkins

```bash
cd /path/to/G-DOP-500-STG-5-1-whanos-6
docker compose restart jenkins
sleep 30
docker exec -u root whanos-jenkins chmod 666 /var/run/docker.sock
```

### Voir les logs en temps réel

```bash
docker logs -f whanos-jenkins
```

### Vérifier les images buildées

```bash
# Dans Jenkins container
docker exec whanos-jenkins docker images | grep whanos

# Sur l'hôte
docker images | grep whanos
```

### Arrêter proprement

```bash
docker compose down
```

### Rebuild complet (si problèmes persistants)

```bash
cd /path/to/G-DOP-500-STG-5-1-whanos-6

# Arrêt
docker compose down

# Rebuild sans cache
docker build --no-cache -t whanos-jenkins -f jenkins/Dockerfile .

# Redémarrage
docker compose up -d jenkins
sleep 30
docker exec -u root whanos-jenkins chmod 666 /var/run/docker.sock
```

---

## Checklist Avant de Commencer

- [ ] Docker Desktop est lancé
- [ ] Port 8080 est libre
- [ ] Au moins 8GB RAM disponible
- [ ] Au moins 20GB d'espace disque
- [ ] Git est installé
- [ ] Tu es à la **racine** du projet (pas dans `jenkins/`)

---

## Ressources

- Jenkins UI : http://localhost:8080
- Credentials : admin / admin
- Documentation projet : `docs/ARCHITECTURE.md`, `docs/BUILD_AND_TEST.md`

---

## Support

Si tu rencontres d'autres problèmes :

1. Vérifie les logs : `docker logs whanos-jenkins`
2. Vérifie les permissions Docker (Problème 1)
3. Vérifie que tu es à la racine pour build
4. N'oublie pas d'approuver les scripts (Problème 2)
