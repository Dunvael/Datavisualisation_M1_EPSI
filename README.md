# Datavisualisation_M1_EPSI

```
tp-dataviz/
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
├── loki/                       # (Optionnel si tu fais aussi les logs)
│   ├── loki-config.yml
│   └── promtail-config.yml
│
├── logs/                       # (Optionnel) dossier local pour logs custom
│
└── README.md                   # (facultatif, pour décrire ton TP)
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
| **logs/** *(optionnel)*                              | Si tu veux y rediriger des logs de services ou de tests manuels.                                          |
| **README.md**                                        | Notes de ton TP, commandes utiles, etc.                                                                   |

___

## 💾 Volumes persistants créés par Docker

| Volume         | Contenu persisté                         | Monté où ?         |
| -------------- | ---------------------------------------- | ------------------ |
| `prom_data`    | Base de données interne de Prometheus    | `/prometheus`      |
| `grafana_data` | Dashboards, datasources, comptes Grafana | `/var/lib/grafana` |
| `mysql_data`   | Données MySQL (tables, users, etc.)      | `/var/lib/mysql`   |
| `loki_data`    | Logs stockés par Loki (si activé)        | `/loki`            |

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

Toujours dans Ubuntu/WSL (clône ton repo ici : ~/tp-dataviz).

### Cloner le repo (si pas déjà fait dans WSL)

git clone <URL_DE_REPO> ~/tp-dataviz
cd ~/tp-dataviz

### Démarrer MySQL puis créer l’utilisateur pour l’exporter

docker compose up -d mysql

***Attendre ~10s puis créer l'utilisateur pour l'exporter***

docker exec -it mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "
CREATE USER IF NOT EXISTS '${MYSQL_EXPORTER_USER}'@'%' IDENTIFIED BY '${MYSQL_EXPORTER_PASSWORD}';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO '${MYSQL_EXPORTER_USER}'@'%';
FLUSH PRIVILEGES;
"

### 1) Démarrer la stack “métriques”

docker compose up -d prometheus grafana mysqld-exporter node-exporter-host node-exporter-node2

### 2) Démarrer la stack “logs”

docker compose up -d loki promtail

___

## Vérifications rapides

### Voir l’état des conteneurs

docker compose ps

### Logs d’un service si besoin

docker compose logs -f prometheus

### Prometheus up ?

curl -sf http://localhost:9090/-/healthy && echo "Prometheus OK"

### Cibles Prometheus (doivent être "UP")

curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[].health' | sort | uniq -c

### Grafana accessible ?

curl -I http://localhost:3000 | head -n1

### MySQL ping (via client dans le conteneur)

docker exec -it mysql mysql -utpuser -ptppass -e "SELECT 1;" tpdb

### Node Exporter host

curl -s http://localhost:9100/metrics | head

### 2e Node Exporter

curl -s http://localhost:9101/metrics | head

### mysqld-exporter

curl -s http://localhost:9104/metrics | grep -E 'mysql_global_status|mysql_up' | head

### Loki / labels connus

curl -s "http://localhost:3100/loki/api/v1/labels" | jq '.status'

### Promtail web UI (metrics/targets)

curl -I http://localhost:9080

### Vérifier les données persistantes via volumes : prom_data, grafana_data, mysql_data, loki_data

docker volume ls

___

## Accès web

Grafana → http://localhost:3000
 (admin / admin)
Datasources Prometheus et Loki déjà provisionnées.

Prometheus → http://localhost:9090
 → Status → Targets : tout doit être UP.

Loki (API) → http://localhost:3100/ready

___

## Nettoyage / persistance

### Stopper

docker compose down

### Tout remettre à zéro (⚠️ supprime les données)

docker compose down -v