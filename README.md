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

## Déploiement de tout le TP (script auto deploy.sh)

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

### Vérifier les données persistantes via volumes : prom_data, grafana_data, mysql_data, loki_data

```Bash
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

```Bash
docker compose down
```

### Tout remettre à zéro (⚠️ supprime les données)

```Bash
docker compose down -v
```