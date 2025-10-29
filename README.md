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

## Commandes (déploiement)

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
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health: .health}'


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