# Datavisualisation_M1_EPSI

```
tp-dataviz/
│
├── .gitignore
│
├── docker-compose.yml
│
├── prometheus/
│   └── prometheus.yml
│
├── grafana/
│   └── provisioning/
│       └── datasources/
│           └── datasources.yml
│
├── loki/                       
│   ├── loki-config.yml
│   └── promtail-config.yml
│
├── logs/                       
│
└── README.md                  
```

___

## 📁 Détails de chaque dossier

| Dossier / Fichier                                    | Rôle                                                                                                      |
| ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| **docker-compose.yml**                               | Le fichier principal : définit tous les services Docker, leurs ports, volumes, dépendances, réseaux, etc. |
| **prometheus/prometheus.yml**                        | Configuration de Prometheus : quels exporters scraper, intervalle, etc.                                   |
| **grafana/provisioning/datasources/datasources.yml** | Auto-provisioning des connexions Grafana (Prometheus et Loki).                                            |
| **loki/loki-config.yml** *(optionnel)*               | Configuration du moteur de logs Loki.                                                                     |
| **loki/promtail-config.yml** *(optionnel)*           | Configuration de Promtail pour collecter les logs Docker.                                                 |
| **logs/** *(optionnel)*                              | Redirige les logs de services ou de tests manuels.                                          |
| **README.md**                                        | Notes du TP, commandes utiles, etc.                                                                   |

___

## 💾 Volumes persistants créés par Docker

| Volume         | Contenu persisté                         | Monté où ?         |
| -------------- | ---------------------------------------- | ------------------ |
| `prom_data`    | Base de données interne de Prometheus    | `/prometheus`      |
| `grafana_data` | Dashboards, datasources, comptes Grafana | `/var/lib/grafana` |
| `mysql_data`   | Données MySQL (tables, users, etc.)      | `/var/lib/mysql`   |
| `loki_data`    | Logs stockés par Loki                    | `/loki`            |

___

## Notes utiles

Versions figées :

* Grafana 12.2.0 (ou patch 12.2.x quand dispo) <https://github.com/grafana/grafana/releases?utm_source=chatgpt.com>
* Prometheus v3.7.2 <https://github.com/prometheus/prometheus/releases?utm_source=chatgpt.com>
* Node Exporter v1.10.2 <https://github.com/prometheus/node_exporter/releases?utm_source=chatgpt.com>
* mysqld-exporter v0.18.0 <>
* MySQL 8.4.7 (LTS) <https://github.com/prometheus/mysqld_exporter/releases?utm_source=chatgpt.com>
* Loki 3.5.7 & Promtail 3.5.7 (Promtail en LTS) <https://github.com/grafana/loki/releases>
* Pourquoi 8.4.x (LTS) pour MySQL ? Cycle LTS documenté : stabilité recommandée pour TP & prod. <https://endoflife.date/mysql?utm_source=chatgpt.com>
* Promtail : en LTS depuis fév. 2025 mais parfaitement utilisable pour ce TP. <https://grafana.com/docs/loki/latest/send-data/promtail/?utm_source=chatgpt.com>

___

## Résolution erreurs

### MySQL qui ne démarre pas

Pour MySQL 8.4.7 on supprime la `directive command` dans la catégorie `environnement` de la partie `MySql` dans le docker-compose.  
En effet, MySQL 8.4.7 n’a plus besoin (et n’accepte plus) `--default-authentication-plugin=mysql_native_password`. Le laisser provoque une erreur.  
Le plugin par défaut caching_sha2_password est désormais standard.

| Plugin                  | Description                                             | Support                            |
| ----------------------- | ------------------------------------------------------- | ---------------------------------- |
| `mysql_native_password` | Ancien mode d’auth (MySQL ≤ 8.0)                        | Déprécié / retiré en 8.4           |
| `caching_sha2_password` | Authentification sécurisée par SHA-256 avec cache local | Par défaut en 8.4 (et plus rapide) |

👉 Prometheus mysqld-exporter supporte parfaitement caching_sha2_password, donc aucune action particulière n’est nécessaire.
On aurait eu besoin de mysql_native_password uniquement pour de très vieux connecteurs PHP ou Python.

### Loki qui ne démarre pas

Le souci vient de Loki qui ne démarre pas à cause de la config. Les logs disent clairement que j'utilises store: boltdb-shipper, mais Loki 3.x exige :

* soit d’autoriser l’absence de structured metadata (allow_structured_metadata: false),
* soit de passer au schéma tsdb (plus avancé).

Et avec boltdb-shipper, il manque les chemins active_index_directory et cache_location (ou un path_prefix global).

La correction la plus simple pour le TP est de rester en boltdb-shipper et d’ajouter les champs manquants + de désactiver structured metadata.

#### *Modification du loki-config.yml : Points clés :*

* limits_config.allow_structured_metadata: false ➜ supprime l’obligation d’un index tsdb.

* storage_config.boltdb_shipper.active_index_directory + cache_location ➜ requis avec boltdb-shipper.

* common.path_prefix: /loki ➜ simplifie les chemins dans le volume loki_data déjà monté.

Résolution en plus : l’erreur vient de clés YAML obsolètes / incorrectes pour Loki 3.x dans storage_config.  
En 3.x :

* storage_config.filesystem n’accepte plus chunks_directory/rules_directory → il faut directory.
* Dans boltdb_shipper, la clé shared_store n’existe plus → à supprimer.

Le message sur allow_structured_metadata est déjà réglé (mis à false).

```
    ...
  storage:
    filesystem: {}        # OK pour 3.x
    ...
    directory: /loki/chunks           # <- remplace chunks_directory/rules_directory
```

***À quoi sert sed -i 's/\r$//' loki/loki-config.yml ?***

Sous Windows, certains fichiers sont enregistrés en CRLF (fin de ligne \r\n).  
Beaucoup d’outils Linux (dont Loki) attendent des fins de ligne LF (\n) uniquement.

La commande sed -i 's/\r$//' ... supprime le \r en fin de ligne → convertit CRLF → LF sans toucher au reste.

C’est exactement ce qui empêchait Loki de parser la config.

Rajout de ces commandes dans le script de déploiement :

```
echo
echo "=== 🧼 Normalisation des fins de ligne (CRLF → LF) sur les configs Loki/Promtail ==="
# Ces sed sont idempotents (sans effet si déjà en LF)
sed -i 's/\r$//' loki/loki-config.yml || true
sed -i 's/\r$//' loki/promtail-config.yml || true
```

### Problème de node "misbehaving"

Sur GitHub, pour mysqld_exporter ≥ 0.15.0 : *“The exporter no longer supports the monolithic DATA_SOURCE_NAME environment variable… use my.cnf or command line arguments.”*

👉 Conclusion : j'utilises l’image v0.18.0 mais elle n’interprète plus DATA_SOURCE_NAME.

Comme aucune autre config n’est fournie, l’exporter essaie un .my.cnf par défaut → erreur → il plante → conteneur s’arrête →
Prometheus n’arrive même plus à résoudre le nom mysqld-exporter → no such host / server misbehaving.

**Correction pour mysqld-exporter** : Garder la version 0.18.0, mais changer la config pour utiliser les arguments CLI à la place de DATA_SOURCE_NAME. De plus, depuis la v0.15.0, le mot de passe doit être passé via la variable d’environnement MYSQLD_EXPORTER_PASSWORD, et les flags sont --mysqld.address et --mysqld.username

Dans le docker-compose.yml, remplacement du bloc :

```
  mysqld-exporter:
    image: prom/mysqld-exporter:v0.18.0
    container_name: mysqld-exporter
    environment:
      - DATA_SOURCE_NAME=${MYSQL_EXPORTER_USER}:${MYSQL_EXPORTER_PASSWORD}@(${MYSQL_HOST}:${MYSQL_PORT})/
    depends_on: [mysql]
    ports:
      - "9104:9104"
    networks: [monitoring]
```

Par ce bloc :

```
  mysqld-exporter:
    image: prom/mysqld-exporter:v0.18.0
    container_name: mysqld-exporter
    depends_on:
      - mysql
    environment:
      - MYSQLD_EXPORTER_PASSWORD=${MYSQL_EXPORTER_PASSWORD}
    command:
      - '--mysqld.address=${MYSQL_HOST}:${MYSQL_PORT}'
      - '--mysqld.username=${MYSQL_EXPORTER_USER}'
    ports:
      - "9104:9104"
    networks:
      - monitoring
    restart: unless-stopped
```

On continue à utiliser les variables du fichier .env (MYSQL_HOST, MYSQL_PORT, MYSQL_EXPORTER_USER, MYSQL_EXPORTER_PASSWORD), mais cette fois correctement interprétées par l’exporter.

Pour le node-exporter-node2 DOWN : Prometheus dit juste : *lookup node-exporter-node2 ... no such host*

Donc le conteneur node-exporter-node2 n’est pas en cours d’exécution (ou a crash). Fiabilisation avec un restart :

Dans docker-compose.yml, pour ce service :

```
  node-exporter-node2:
    image: prom/node-exporter:v1.10.2
    container_name: node-exporter-node2
#    command:
#      - '--collector.disable-defaults=false'
    ports:
      - "9101:9100"
    networks: [monitoring]
    restart: unless-stopped
```

Puis : 

```
# Recharger uniquement les services concernés
docker compose up -d mysqld-exporter node-exporter-node2

# Vérifier qu’ils tournent bien
docker compose ps -a

# Vérifier sur Prometheus
curl -s http://localhost:9090/api/v1/targets | grep -E 'mysqld_exporter|node_exporter_node2'

## Vérifier que l’exporter MySQL répond
curl -s http://localhost:9104/metrics | head
```

**Problème mysqld-exporter** : il redémarre car la connexion MySQL échoue

Le log disait clairement : *failed to validate config: no user specified
Error parsing host config file .my.cnf*

👉 Donc les variables d’environnement .env ne sont pas prises ou elles sont vides.

Le fichier. env comprend bien les bonnes variables et correctement écrites et il est bien récupéré pendant le script deploy.sh.

**Problème node-exporter-node2** : il redémarre car la commande est mauvaise

J'utilises :

```
node-exporter-node2:
  command:
    - '--collector.disable-defaults=false'
```

Or cette option n’existe plus depuis node-exporter 1.3 → Le container crash immédiatement. 

✔️ Je mets une commande vide (le node exporter fonctionne sans rien) :

```
node-exporter-node2:
  image: prom/node-exporter:v1.10.2
  container_name: node-exporter-node2
  ports:
    - "9101:9100"
  networks: [monitoring]
  restart: unless-stopped
```

## Déploiement de tout le TP (script auto deploy.sh)

### 1. Télécharger images

```
docker compose pull
```

### 2. Démarrer MySQL

```
docker compose up -d mysql
```

### 3. Attendre qu’il soit prêt/disponibilité

```
until docker exec mysql mysqladmin ping -p"$MYSQL_ROOT_PASSWORD" --silent 2>/dev/null; do echo "⏳"; sleep 2; done
```

### 4. Créer utilisateur exporter

```
cat <<SQL | docker exec -i mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD"
CREATE USER IF NOT EXISTS '${MYSQL_EXPORTER_USER}'@'%' IDENTIFIED BY '${MYSQL_EXPORTER_PASSWORD}';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO '${MYSQL_EXPORTER_USER}'@'%';
FLUSH PRIVILEGES;
SQL
```

### 5. Démarrer tout le stack (métriques et logs)

```
docker compose up -d prometheus grafana mysqld-exporter node-exporter-host node-exporter-node2 loki promtail
```

### 6. Vérifier

```
docker compose ps
curl -sf http://localhost:9090/-/healthy && echo "✅ Prometheus OK"
curl -I http://localhost:3000 | head -n1
curl -sf http://localhost:3100/ready && echo "✅ Loki OK"
```
___

## Commandes (déploiement)

### Autorisations exécution du script automatique deploy.sh

```
chmod +x deploy.sh
```

### Télécharger les images distantes aux bonnes versions (Optionnel mais recommandé)

```
docker compose pull
```

### Lance les conteneurs (et fait un pull automatique si besoin) => Obligatoire

| Commande                                  | Effet                                                            |
| ----------------------------------------- | ---------------------------------------------------------------- |
| `docker compose up -d mysql`              | Lance **uniquement** le service `mysql`                          |
| `docker compose up -d`                    | Lance **tous les services** définis dans le `docker-compose.yml` |
| `docker compose up -d prometheus grafana` | Lance **uniquement** les services listés                         |


### Attendre que MySQL réponde (boucle automatique)

```
until docker exec mysql mysqladmin ping -p"$MYSQL_ROOT_PASSWORD" --silent 2>/dev/null; do
  echo "⏳ Attente MySQL…"; sleep 2
done
echo "✅ MySQL prêt"
```

### Exécuter les requêtes SQL proprement et créer l’utilisateur pour l’exporter

```
cat <<SQL | docker exec -i mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD"
CREATE USER IF NOT EXISTS '${MYSQL_EXPORTER_USER}'@'%' IDENTIFIED BY '${MYSQL_EXPORTER_PASSWORD}';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO '${MYSQL_EXPORTER_USER}'@'%';
FLUSH PRIVILEGES;
SQL
echo "✅ Utilisateur exporter créé/à jour"
```

### 1) Démarrer la stack “métriques”

```
docker compose up -d prometheus grafana mysqld-exporter node-exporter-host node-exporter-node2
```

### 2) Démarrer la stack “logs”

```
docker compose up -d loki promtail
```

### 3) Démarrer toute la stack (les métriques et les logs)

```
docker compose up -d prometheus grafana mysqld-exporter node-exporter-host node-exporter-node2 loki promtail
```

___

![Loki prêt](../Images/Dataviz/loki_ready.png)

-> Loki est complètement opérationnel, il charge les logs, et l’API répond correctement.
Aucun redémarrage en boucle, et le montage de volumes fonctionne.

![Prometheus status node OK](../Images/Dataviz/prometheus_ok.png)

-> Prometheus scrape correctement toutes les métriques, y compris MySQL.
Donc ton exporter reçoit maintenant les bons identifiants depuis le .env.
Le problème "no user specified / .my.cnf not found" est réglé.

**Tous les targets sont 1/1 UP** :

* mysqld_exporter → 🟢 UP
* node_exporter_host → 🟢 UP
* node_exporter_node2 → 🟢 UP
* prometheus → 🟢 UP

![Grafana OK](../Images/Dataviz/grafana_ok.png)

-> Grafana :

* Loki (http://loki:3100)
* Prometheus (http://prometheus:9090) (défaut)

Ces sources sont actives, donc je peux :

* créer un dashboard MySQL / Node / Host
* explorer les logs via Loki

✅ Déploiement complet terminé avec succès :  

* Grafana → <http://localhost:3000> (admin / admin ou identifiants .env)  
* Prometheus → <http://localhost:9090>  
* Loki API → <http://localhost:3100/ready>  

___

## Vérifications rapides

### Voir l’état des conteneurs

```
docker compose ps
```

### Logs d’un service si besoin

```
docker compose logs -f prometheus
```

### Prometheus up ?

```
curl -sf http://localhost:9090/-/healthy && echo "✅ Prometheus OK" || echo "❌ Prometheus KO"

```

### Cibles Prometheus (doivent être "UP")

#### Sans jq

```
curl -s http://localhost:9090/api/v1/targets
```

#### Avec jq pour sortie propre

```
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[].health' | sort | uniq -c
```

### (Optionnel, avec jq pour sortie propre)

```
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health: .health}'
```

### Grafana accessible ?

```
curl -I http://localhost:3000 | head -n1
```

### MySQL ping (via client dans le conteneur)

```
docker exec -it mysql mysql -utpuser -ptppass -e "SELECT 1;" tpdb
```

### Node Exporter host

```
curl -s http://localhost:9100/metrics | head
```

### 2e Node Exporter

```
curl -s http://localhost:9101/metrics | head
```

### mysqld-exporter actif (mysql_up doit valoir 1)

```
curl -s http://localhost:9104/metrics | grep -E 'mysql_global_status|mysql_up' | head
```

### Loki / labels connus

```
curl -s "http://localhost:3100/loki/api/v1/labels" | jq '.status'
```

### Promtail web UI (metrics/targets)

```
curl -I http://localhost:9080
```

### Vérifier les données persistantes via volumes : prom_data, grafana_data, mysql_data, loki_data

```
docker volume ls
```

___

## Accès web

Grafana → <http://localhost:3000>
 (admin / admin)
Datasources Prometheus et Loki déjà provisionnées.

Prometheus → <http://localhost:9090>
 → Status → Targets : tout doit être UP.

Loki (API) → <http://localhost:3100/ready>

___

## Nettoyage / persistance

### Stopper

```
docker compose down
```

### Tout remettre à zéro (⚠️ supprime les données)

```
docker compose down -v
```