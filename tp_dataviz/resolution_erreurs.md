# Résolution erreurs

## MySQL qui ne démarre pas

Pour MySQL 8.4.7 on supprime la `directive command` dans la catégorie `environnement` de la partie `MySql` dans le docker-compose.  
En effet, MySQL 8.4.7 n’a plus besoin (et n’accepte plus) `--default-authentication-plugin=mysql_native_password`. Le laisser provoque une erreur.  
Le plugin par défaut caching_sha2_password est désormais standard.

| Plugin                  | Description                                             | Support                            |
| ----------------------- | ------------------------------------------------------- | ---------------------------------- |
| `mysql_native_password` | Ancien mode d’auth (MySQL ≤ 8.0)                        | Déprécié / retiré en 8.4           |
| `caching_sha2_password` | Authentification sécurisée par SHA-256 avec cache local | Par défaut en 8.4 (et plus rapide) |

👉 Prometheus mysqld-exporter supporte parfaitement caching_sha2_password, donc aucune action particulière n’est nécessaire.
On aurait eu besoin de mysql_native_password uniquement pour de très vieux connecteurs PHP ou Python.

## Loki qui ne démarre pas

Le souci vient de Loki qui ne démarre pas à cause de la config. Les logs disent clairement que j'utilises store: boltdb-shipper, mais Loki 3.x exige :

* soit d’autoriser l’absence de structured metadata (allow_structured_metadata: false),
* soit de passer au schéma tsdb (plus avancé).

Et avec boltdb-shipper, il manque les chemins active_index_directory et cache_location (ou un path_prefix global).

La correction la plus simple pour le TP est de rester en boltdb-shipper et d’ajouter les champs manquants + de désactiver structured metadata.

### *Modification du loki-config.yml : Points clés :*

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

## Problème de node "misbehaving"

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