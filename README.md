# Datavisualisation_M1_EPSI

___

## Sommaire

* Architecture du projet
* Structure du repository
* Prérequis et fichier `.env`
* Détails de chaque dossier
* Volumes persistants Docker
* Diagramme d'architecture
* Versions utilisées
* SLI / SLO et seuils
* Justification des requêtes PromQL
* Alertes configurées
* Déploiement du projet (script auto deploy.sh)
* Commandes (déploiement)
* Test d’incident Loki
* Vérifications rapides
* Accès aux interfaces
* Nettoyage / persistance

___

## Architecture du projet
Ce projet met en place une stack d’observabilité complète basée sur :

- **Prometheus** → collecte des métriques
- **Grafana** → visualisation des métriques et logs
- **Loki** → agrégation des logs
- **Promtail** → collecte des logs des conteneurs
- **Node Exporter** → métriques système
- **mysqld_exporter** → métriques MySQL
- **Alertmanager** → gestion des alertes

Stack d’observabilité :

```
Application / MySQL
        │
        ▼
Exporters
(node_exporter / mysqld_exporter)
        │
        ▼
Prometheus
(scraping métriques)
        │
        ├── Alertmanager (gestion alertes)
        │
        ▼
Grafana
(dashboards & visualisation)
        │
        ▼
Logs
Promtail → Loki → Grafana
```

Cette architecture permet de superviser une infrastructure complète :

* métriques système
* métriques base de données
* logs applicatifs
* dashboards Grafana
* alerting Prometheus

___

## Structure du repository

```
Datavisualisation_M1_EPSI/
│
├── tp_dataviz/
│   │
│   ├── .gitignore
│   ├── .env (non versionné)
│   ├── .env.example
│   ├── deploy.sh
│   ├── docker-compose.yml
│   ├── incident_loki_test.sh
│   ├── resolution_erreurs.md
│   │
│   ├── alertmanager/
│   │   └── alertmanager.yml
│   │
│   ├── grafana/
│   │   ├── dashboards/
│   │   │   ├── api/
│   │   │   │   ├── tp-api-n1.json
│   │   │   │   └── tp-api-n2-diagnostic.json
│   │   │   └── infra/
│   │   │       └── tp-stack-overview.json
│   │   └── provisioning/
│   │       ├── dashboards/
│   │       │   └── dashboards.yml
│   │       └── datasources/
│   │           └── datasources.yml
│   │
│   ├── loki/
│   │   ├── loki-config.yml
│   │   └── promtail-config.yml
│   │
│   └── prometheus/
│       ├── prometheus.yml
│       └── rules/
│           ├── alerts.yml
│           └── recording.yml
│
├── README.md
└── projet_grafana.pdf              
```
___

### Prérequis et fichier `.env`

Avant de lancer le projet, il est nécessaire de créer un fichier `.env` à la racine du dossier `tp_dataviz/` (il doit être au même niveau que le fichier deploy.sh).

Ce fichier contient les variables d’environnement nécessaires au bon fonctionnement de la stack, notamment :

- les identifiants MySQL
- le mot de passe root MySQL
- les identifiants de l’utilisateur utilisé par `mysqld_exporter`
- les identifiants Grafana

*Attention* : Pour des questions de sécurité, il est nécessaire d'ajouter ce fichier `.env` au fichier `.gitignore`. Le fichier `.env` ne doit pas être versionné sur GitHub, car il contient des informations sensibles.  
Un fichier **`.env.example`** est fourni pour montrer la structure attendue, il suffit de modifier les valeurs de chaque variable.

___

### Détails de chaque dossier

| Dossier / Fichier                                    | Rôle                                                                             |
| ---------------------------------------------------- | -------------------------------------------------------------------------------- |
| **tp_dataviz/**                                      | Dossier principal contenant toute la stack d’observabilité.                      |
| **.gitignore**                                       | Empêche certains fichiers locaux d’être poussés sur GitHub.                      |
| **docker-compose.yml**                               | Définit tous les services Docker (Prometheus, Grafana, Loki, MySQL, exporters…). |
| **.env**                                             | Définit toutes les variables nécessaires au bon fonctionnement de la stack. |
| **deploy.sh**                                        | Script automatisé pour déployer toute la stack.                                  |
| **incident_loki_test.sh** | Script de génération d’un incident simulé pour produire des logs `INFO/WARN/ERROR` visibles dans Loki via Promtail. |
| **resolution_erreurs.md**                            | Notes et procédures de résolution d’erreurs rencontrées pendant le TP.           |
| **alertmanager/alertmanager.yml**                    | Configuration d’Alertmanager pour gérer les alertes Prometheus.                  |
| **prometheus/prometheus.yml**                        | Configuration principale de Prometheus : scraping des métriques.                 |
| **prometheus/rules/alerts.yml**                      | Règles d’alerte Prometheus (CPU, MySQL down, etc.).                              |
| **prometheus/rules/recording.yml**                   | Recording rules Prometheus pour optimiser les requêtes.                          |
| **grafana/provisioning/datasources/datasources.yml** | Datasources Grafana configurées automatiquement (Prometheus et Loki).            |
| **grafana/provisioning/dashboards/dashboards.yml**   | Chargement automatique des dashboards Grafana.                                   |
| **grafana/dashboards/**                              | Dashboards Grafana versionnés dans le projet.                                    |
| **grafana/dashboards/infra/tp-stack-overview.json**  | Dashboard principal affichant l’état global de l’infrastructure.                 |
| **loki/loki-config.yml**                             | Configuration du moteur de logs Loki.                                            |
| **loki/promtail-config.yml**                         | Configuration de Promtail pour collecter les logs Docker.                        |
| **README.md**                                        | Documentation complète du projet.                                                |
| **projet_grafana.pdf**                               | Documentation du projet et présentation du TP.                                   |
| **.env.example** | Modèle de variables d’environnement à copier en `.env` avant le déploiement. |
| **grafana/dashboards/api/tp-api-n1.json** | Dashboard principal N1 orienté vue synthétique de l’API : disponibilité, trafic, erreurs, latence, corrélation avec l’infrastructure. |
| **grafana/dashboards/api/tp-api-n2-diagnostic.json** | Dashboard secondaire N2 orienté diagnostic détaillé : endpoints lents, erreurs par endpoint, logs applicatifs, CPU/RAM, état de l’API. |

___

## Volumes persistants Docker

| Volume              | Contenu persisté                         | Monté où ?         |
| ------------------- | ---------------------------------------- | ------------------ |
| `prom_data`         | Base de données interne de Prometheus    | `/prometheus`      |
| `grafana_data`      | Dashboards, datasources, comptes Grafana | `/var/lib/grafana` |
| `mysql_data`        | Données MySQL (tables, users, etc.)      | `/var/lib/mysql`   |
| `loki_data`         | Logs stockés par Loki                    | `/loki`            |
| `alertmanager_data` | État interne d’Alertmanager              | `/alertmanager`    |

___

## Diagramme d'architecture

<img width="2079" height="1169" alt="diagram_infra" src="https://github.com/user-attachments/assets/f21ec3b7-2119-4270-bbce-762ad8af09bd" />

### Explication de l'architecture

| Composant           | Rôle                                                      |
| ------------------- | --------------------------------------------------------- |
| **MySQL**           | Base de données supervisée                                |
| **node_exporter**   | Collecte les métriques système (CPU, RAM, disque, réseau) |
| **mysqld_exporter** | Expose les métriques MySQL pour Prometheus                |
| **Prometheus**      | Scrape les métriques des exporters                        |
| **Alertmanager**    | Gère et route les alertes Prometheus                      |
| **Promtail**        | Collecte les logs des conteneurs                          |
| **Loki**            | Stocke et indexe les logs                                 |
| **Grafana**         | Visualisation des métriques et logs                       |

### Flux de données

1️ - Exporters exposent les métriques  
2️ - Prometheus scrape les métriques  
3️ - Alertmanager reçoit les alertes  
4️ - Promtail collecte les logs Docker  
5️ - Loki stocke les logs  
6️ - Grafana visualise métriques + logs  

___

## Versions utilisées

- Grafana 12.2.0
- Prometheus v3.7.2
- Node Exporter v1.10.2
- mysqld-exporter v0.18.0
- MySQL 8.4.7 (LTS)
- Alertmanager v0.28.1
- Loki 3.5.7
- Promtail 3.5.7
- Demo App `quay.io/brancz/prometheus-example-app:v0.3.0`

___

## Justification des requêtes PromQL

Les dashboards et alertes reposent sur des requêtes PromQL documentées.  
Le projet suit l’idée demandée dans le sujet : utiliser des requêtes lisibles, limiter la cardinalité, travailler avec des fenêtres cohérentes (`[5m]`) et utiliser des **recording rules** pour éviter de recalculer en permanence les expressions coûteuses.

### 1. Disponibilité de l’API

```promql
max(up{job="demo_app",instance="$instance"}) or on() vector(0)
```

Rôle : vérifier si l’instance sélectionnée de l’application est joignable par Prometheus.
Pourquoi cette requête :

* up est l’indicateur standard de succès d’un scrape Prometheus
* max(...) garantit une valeur simple à afficher dans un panneau stat
* or on() vector(0) permet d’obtenir 0 même si aucune série n’est retournée, ce qui évite un panneau vide

### 2. Trafic applicatif (req/s)

```promql
sum(clamp_min(demo_app:http_requests:rate5m_total{instance="$instance"}, 0)) or on() vector(0)
```

Rôle : mesurer le débit de requêtes HTTP de l’application.
Pourquoi cette requête :

* la métrique affichée provient d’une recording rule calculée à partir de rate(http_requests_total[5m])
* la fenêtre de 5 minutes lisse les variations trop brutales
* clamp_min(..., 0) évite l’affichage de valeurs négatives liées à d’éventuels resets de compteur
cela permet une lecture simple du trafic moyen récent

### 3. Taux d’erreur HTTP

```promql
(clamp_min(demo_app:http_errors:ratio5m, 0) or on() vector(0)) * 100
```

Rôle : mesurer le pourcentage de requêtes en erreur (4xx et 5xx).
Pourquoi cette requête :

* le ratio d’erreur est plus utile qu’un simple nombre brut car il tient compte du volume de trafic
* la recording rule encapsule la formule :
   * erreurs = requêtes 4xx|5xx
   * total = toutes les requêtes
* la multiplication par 100 permet un affichage direct en pourcentage
cette métrique sert aussi de base à l’alerte métier

### 4. Latence p95 de l’API

```promql
(clamp_min(demo_app:http_request_duration_seconds:p95_5m, 0) or on() vector(0)) * 1000
```

Rôle : afficher le 95e percentile du temps de réponse.
Pourquoi cette requête :

* le p95 est plus représentatif qu’une moyenne simple
* la recording rule repose sur histogram_quantile(0.95, sum by (le)(rate(..._bucket[5m])))
* la fenêtre 5 minutes lisse les fluctuations
* la multiplication par 1000 transforme les secondes en millisecondes pour un affichage plus parlant

### 5. Saturation CPU hôte

```promql
clamp_min(
  100 - (
    avg by(instance) (
      rate(node_cpu_seconds_total{job=~"node_exporter_host|node_exporter_node2",mode="idle",instance="$node_instance"}[5m])
    ) * 100
  ),
  0
) or on() vector(0)
```

Rôle : mesurer l’utilisation CPU du nœud surveillé.
Pourquoi cette requête :

* node_cpu_seconds_total{mode="idle"} mesure le temps CPU inactif
* 100 - idle% donne donc le taux d’utilisation
* avg by(instance) agrège les cœurs CPU d’une machine
* la fenêtre [5m] évite de réagir à un pic très court
* cette métrique sert à corréler une saturation hôte avec une hausse de latence API

### 6. Saturation mémoire hôte

```promql
((1 - (node_memory_MemAvailable_bytes{instance="$node_instance"} / node_memory_MemTotal_bytes{instance="$node_instance"})) * 100) or on() vector(0)
```

Rôle : mesurer le pourcentage de mémoire utilisée.
Pourquoi cette requête :

* MemAvailable est plus pertinent que MemFree sur Linux
* le ratio mémoire utilisée / mémoire totale donne une lecture simple en pourcentage
* cette métrique aide à identifier une saturation durable du nœud

### 7. Occupation disque

```promql
(100 * (
  1 - (
    sum(node_filesystem_avail_bytes{instance="$node_instance",fstype!~"tmpfs|overlay|squashfs|nsfs",mountpoint!~"/(sys|proc|dev|run)($|/)"})
    /
    sum(node_filesystem_size_bytes{instance="$node_instance",fstype!~"tmpfs|overlay|squashfs|nsfs",mountpoint!~"/(sys|proc|dev|run)($|/)"})
  )
)) or on() vector(0)
```

Rôle : mesurer l’occupation disque utile.
Pourquoi cette requête :

* exclusion des pseudo-filesystems (tmpfs, overlay, squashfs, etc.) pour ne garder que les volumes pertinents
* on calcule le ratio espace disponible / espace total, puis on en déduit le pourcentage utilisé
* utile pour détecter un risque de saturation stockage

### 8. Top endpoints les plus lents

```promql
topk(5, clamp_min(demo_app:http_request_duration_seconds:p95_5m:by_handler, 0))
```

Rôle : identifier les 5 endpoints les plus lents.
Pourquoi cette requête :

* topk(5, ...) est demandé dans le sujet comme type de requête utile
* la mesure par handler permet d’orienter directement le diagnostic vers les routes les plus coûteuses
* l’utilisation d’une recording rule réduit le coût de calcul dans Grafana

### 9. Erreurs par endpoint

```promql
clamp_min(sum by(handler) (rate(http_requests_total{job="demo_app",code=~"4..|5.."}[5m])), 0) or on() vector(0)
```

Rôle : localiser quel endpoint produit le plus d’erreurs.
Pourquoi cette requête :

* agrégation par handler pour identifier rapidement la route fautive
* filtre sur 4xx|5xx pour isoler les réponses anormales
* la fenêtre 5 minutes permet d’observer une tendance récente sans trop de bruit

### 10. Disponibilité MySQL

```promql
max(mysql_up{instance="$mysql_instance"}) or on() vector(0)
```

Rôle : vérifier que MySQL répond correctement via mysqld_exporter.
Pourquoi cette requête :

* mysql_up est l’indicateur standard de disponibilité exposé par l’exporter
* le panneau stat permet de vérifier instantanément l’état de la base
* cet indicateur est essentiel pour corréler un incident applicatif avec la base

### 11. Débit MySQL (QPS)

```promql
rate(mysql_global_status_queries{instance="$mysql_instance"}[5m]) or on() vector(0)
```

Rôle : mesurer le nombre de requêtes SQL par seconde.
Pourquoi cette requête :

* rate() est adapté aux compteurs monotones MySQL
* la fenêtre [5m] fournit une tendance stable
* utile pour distinguer un problème de charge d’un problème de disponibilité

### 12. InnoDB Buffer Pool Hit Ratio

```promql
((1 - (
  mysql_global_status_innodb_buffer_pool_reads{instance="$mysql_instance"}
  /
  ignoring() mysql_global_status_innodb_buffer_pool_read_requests{instance="$mysql_instance"}
)) * 100) or on() vector(0)
```

Rôle : mesurer l’efficacité du cache InnoDB.
Pourquoi cette requête :

* plus le ratio est proche de 100 %, plus les lectures sont servies depuis le buffer pool
* une baisse peut signaler une pression mémoire ou un dimensionnement insuffisant
* c’est un bon indicateur de performance base de données

### Pourquoi utiliser des recording rules ?

Les expressions suivantes ont été pré-calculées dans recording.yml :

* demo_app:http_requests:rate5m
* demo_app:http_requests:rate5m_total
* demo_app:http_errors:ratio5m
* demo_app:http_request_duration_seconds:p95_5m
* demo_app:http_request_duration_seconds:p95_5m:by_instance
* demo_app:http_request_duration_seconds:p95_5m:by_handler

***Intérêt*** :

* alléger les dashboards Grafana
* éviter de recalculer des rate(), sum by(...) et histogram_quantile(...) à chaque rafraîchissement
* améliorer la lisibilité des requêtes finales
* respecter la contrainte du sujet sur les requêtes “propres” et pas trop coûteuses

___


---

## Alertes configurées

### 1. DemoAppHighErrorRate
- **Type** : symptôme métier
- **Expression** : `demo_app:http_errors:ratio5m > 0.02`
- **Fenêtre** : `for: 5m`
- **But** : détecter une hausse durable du taux d’erreur HTTP au-dessus de 2 %
- **Action** : vérifier les endpoints fautifs dans le dashboard N2 et corréler avec les logs Loki

### 2. DemoAppHighLatencyP95
- **Type** : symptôme métier
- **Expression** : `demo_app:http_request_duration_seconds:p95_5m > 0.5`
- **Fenêtre** : `for: 10m`
- **But** : détecter une hausse durable de la latence p95 au-dessus de 500 ms
- **Action** : vérifier CPU/RAM, trafic, endpoints lents et logs applicatifs

### 3. HostHighCPU
- **Type** : saturation infrastructure
- **Expression** : `(1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))) > 0.85`
- **Fenêtre** : `for: 15m`
- **But** : détecter une saturation CPU prolongée au-dessus de 85 %
- **Action** : identifier le nœud concerné et corréler avec la latence et les erreurs applicatives

### 4. PrometheusTargetDown
- **Type** : qualité de collecte
- **Expression** : `up{job=~"prometheus|demo_app|node_exporter_host|node_exporter_node2|mysqld_exporter"} == 0`
- **Fenêtre** : `for: 2m`
- **But** : détecter une cible qui ne répond plus ou dont le scrape échoue
- **Action** : vérifier le conteneur, le réseau Docker et l’endpoint `/metrics`

___

## SLI / SLO et seuils

### SLI retenus

#### 1. Disponibilité applicative
- **SLI** : état `UP` de la cible `demo_app`
- **Métrique utilisée** : `up{job="demo_app"}`
- **Pourquoi** : permet de vérifier immédiatement si Prometheus arrive bien à scrapper l’application, donc si le service est joignable et expose ses métriques.

#### 2. Taux d’erreur HTTP
- **SLI** : proportion de réponses HTTP en erreur (`4xx` + `5xx`) sur l’ensemble des requêtes
- **Métrique utilisée** : `http_requests_total`
- **Pourquoi** : permet de mesurer la qualité de service côté utilisateur et de détecter rapidement une dégradation applicative.

#### 3. Latence p95
- **SLI** : 95e percentile du temps de réponse HTTP
- **Métrique utilisée** : `http_request_duration_seconds_bucket`
- **Pourquoi** : le p95 permet de mesurer une latence représentative sans être trop sensible aux valeurs extrêmes.

### SLO retenu

- **SLO** : conserver un taux d’erreur inférieur à **2 %** sur une fenêtre glissante de **5 minutes**
- **Indicateur associé** : `demo_app:http_errors:ratio5m`
- **Justification** : sur un TP court et une application de démonstration, une fenêtre de 5 minutes permet d’observer rapidement une dérive sans attendre 30 jours. Le seuil de 2 % est assez faible pour signaler une anomalie réelle, sans générer trop de bruit.

### Seuils choisis

- **Erreur > 2 % pendant 5 min** : seuil de dégradation notable du service
- **Latence p95 > 500 ms pendant 10 min** : seuil choisi pour détecter une dégradation perceptible côté utilisateur
- **CPU > 85 % pendant 15 min** : seuil de saturation durable, en évitant les pics trop courts
- **Target down pendant 2 min** : seuil court pour détecter rapidement une perte de collecte ou une indisponibilité

___

## Déploiement du projet (script auto deploy.sh)

### 1. Télécharger images

```Bash
docker compose pull
```

### 2. Démarrer MySQL

```Bash
docker compose up -d mysql
```

### 3. Attendre qu’il soit prêt/disponibilité

```Bash
until docker exec mysql mysqladmin ping -p"$MYSQL_ROOT_PASSWORD" --silent 2>/dev/null; do echo "⏳"; sleep 2; done
```

### 4. Créer utilisateur exporter

```Bash
cat <<SQL | docker exec -i mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD"
CREATE USER IF NOT EXISTS '${MYSQL_EXPORTER_USER}'@'%' IDENTIFIED BY '${MYSQL_EXPORTER_PASSWORD}';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO '${MYSQL_EXPORTER_USER}'@'%';
FLUSH PRIVILEGES;
SQL
```

### 5. Démarrer tout le stack (métriques et logs)

```Bash
docker compose up -d prometheus grafana mysqld-exporter node-exporter-host node-exporter-node2 loki promtail
```

### 6. Vérifier

```Bash
docker compose ps
curl -sf http://localhost:9090/-/healthy && echo "✅ Prometheus OK"
curl -I http://localhost:3000 | head -n1
curl -sf http://localhost:3100/ready && echo "✅ Loki OK"
```
___

## Commandes (déploiement)

### Autorisations exécution du script automatique deploy.sh

```Bash
chmod +x deploy.sh
```

### Télécharger les images distantes aux bonnes versions (Optionnel mais recommandé)

```Bash
docker compose pull
```

### Lance les conteneurs (et fait un pull automatique si besoin) => Obligatoire

| Commande                                  | Effet                                                            |
| ----------------------------------------- | ---------------------------------------------------------------- |
| `docker compose up -d mysql`              | Lance **uniquement** le service `mysql`                          |
| `docker compose up -d`                    | Lance **tous les services** définis dans le `docker-compose.yml` |
| `docker compose up -d prometheus grafana` | Lance **uniquement** les services listés                         |


### Attendre que MySQL réponde (boucle automatique)

```Bash
until docker exec mysql mysqladmin ping -p"$MYSQL_ROOT_PASSWORD" --silent 2>/dev/null; do
  echo "⏳ Attente MySQL…"; sleep 2
done
echo "✅ MySQL prêt"
```

### Exécuter les requêtes SQL proprement et créer l’utilisateur pour l’exporter

```Bash
cat <<SQL | docker exec -i mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD"
CREATE USER IF NOT EXISTS '${MYSQL_EXPORTER_USER}'@'%' IDENTIFIED BY '${MYSQL_EXPORTER_PASSWORD}';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO '${MYSQL_EXPORTER_USER}'@'%';
FLUSH PRIVILEGES;
SQL
echo "✅ Utilisateur exporter créé/à jour"
```

### 1) Démarrer la stack “métriques”

```Bash
docker compose up -d prometheus grafana mysqld-exporter node-exporter-host node-exporter-node2
```

### 2) Démarrer la stack “logs”

```Bash
docker compose up -d loki promtail
```

### 3) Démarrer toute la stack (les métriques et les logs)

```Bash
docker compose up -d prometheus grafana mysqld-exporter node-exporter-host node-exporter-node2 loki promtail
```

___

## Test d’incident Loki

Pour valider la remontée des logs dans Loki, un script `incident_loki_test.sh` est fourni.

Ce script lance un conteneur Docker éphémère qui génère volontairement des logs de type :

- `INFO`
- `WARN`
- `ERROR`

Ces logs sont collectés automatiquement par **Promtail**, puis envoyés vers **Loki** et consultables dans **Grafana**.

### Lancer le test

```bash
chmod +x incident_loki_test.sh
./incident_loki_test.sh
```

### Vérifier dans Grafana / Loki

Exemples de requêtes LogQL :

```logql
{job="docker"} |= "incident=test"
```

```logql
{job="docker"} |= "ERROR"
```

```logql
{job="docker"} |= "demo-app"
```

### Objectif du test

Ce scénario permet de simuler un incident applicatif et de vérifier que :

* les logs Docker sont bien collectés par Promtail
* les logs remontent correctement dans Loki
* ils sont exploitables dans Grafana pour le diagnostic

### Comment l'utiliser

Depuis le dossier `tp_dataviz` :

```Bash
chmod +x incident_loki_test.sh
./incident_loki_test.sh
```

Ensuite dans Grafana > Explore > Loki, rechercher par exemple :

```logql
{job="docker"} |= "incident=test"
```

```logql
{job="docker"} |= "ERROR"
```

```logql
{job="docker"} |= "demo-app"
```

___

## Vérifications rapides

### Voir l’état des conteneurs

```Bash
docker compose ps
```

### Logs d’un service si besoin

```Bash
docker compose logs -f prometheus
```

### Prometheus up ?

```Bash
curl -sf http://localhost:9090/-/healthy && echo "✅ Prometheus OK" || echo "❌ Prometheus KO"

```

### Cibles Prometheus (doivent être "UP")

#### Sans jq

```Bash
curl -s http://localhost:9090/api/v1/targets
```

#### Avec jq pour sortie propre

```Bash
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[].health' | sort | uniq -c
```

### (Optionnel, avec jq pour sortie propre)

```Bash
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health: .health}'
```

### Grafana accessible ?

```Bash
curl -I http://localhost:3000 | head -n1
```

### MySQL ping (via client dans le conteneur)

```Bash
docker exec -it mysql mysql -utpuser -ptppass -e "SELECT 1;" tpdb
```

### Node Exporter host

```Bash
curl -s http://localhost:9100/metrics | head
```

### 2e Node Exporter

```Bash
curl -s http://localhost:9101/metrics | head
```

### mysqld-exporter actif (mysql_up doit valoir 1)

```Bash
curl -s http://localhost:9104/metrics | grep -E 'mysql_global_status|mysql_up' | head
```

### Loki / labels connus

```Bash
curl -s "http://localhost:3100/loki/api/v1/labels" | jq '.status'
```

### Promtail web UI (metrics/targets)

```Bash
curl -I http://localhost:9080
```

### Vérifier les données persistantes via volumes : prom_data, grafana_data, mysql_data, loki_data, alertmanager_data

```Bash
docker volume ls
```

___

## Accès aux interfaces

| Service     | URL                                                        |
| ----------- | ---------------------------------------------------------- |
| Grafana     | [http://localhost:3000](http://localhost:3000)             |
| Prometheus  | [http://localhost:9090](http://localhost:9090)             |
| Loki API    | [http://localhost:3100/ready](http://localhost:3100/ready) |
| Alertmanager| [http://localhost:9093](http://localhost:9093)             |
| Promtail | [http://localhost:9080](http://localhost:9080)                |
| Demo App | [http://localhost:8080](http://localhost:8080)                |

___

## Nettoyage / persistance

### Stopper les conteneurs

```Bash
docker compose down
```

### Tout remettre à zéro (⚠️ Supprimer aussi les volumes)

```Bash
docker compose down -v
```
