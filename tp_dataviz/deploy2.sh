#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
# 🚀 Script de déploiement complet du TP Dataviz
# ─────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ENV_FILE="$SCRIPT_DIR/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ Fichier .env introuvable à la racine du projet : $ENV_FILE"
  exit 1
fi

set -a
. "$ENV_FILE"
set +a

# Vérifier les variables indispensables (secrets + config critique)
: "${MYSQL_ROOT_PASSWORD:?Variable manquante dans .env}"
: "${MYSQL_EXPORTER_USER:?Variable manquante dans .env}"
: "${MYSQL_EXPORTER_PASSWORD:?Variable manquante dans .env}"
: "${MYSQL_HOST:?Variable manquante dans .env}"
: "${MYSQL_PORT:?Variable manquante dans .env}"
: "${GRAFANA_ADMIN_USER:?Variable manquante dans .env}"
: "${GRAFANA_ADMIN_PASSWORD:?Variable manquante dans .env}"

echo "=== 📦 Téléchargement des images ==="
docker compose pull

echo
echo "=== 🧼 Normalisation CRLF → LF sur les configs ==="
sed -i 's/\r$//' prometheus/prometheus.yml || true
sed -i 's/\r$//' loki/loki-config.yml || true
sed -i 's/\r$//' loki/promtail-config.yml || true
if [[ -d prometheus/rules ]]; then sed -i 's/\r$//' prometheus/rules/*.yml || true; fi
if [[ -f alertmanager/alertmanager.yml ]]; then sed -i 's/\r$//' alertmanager/alertmanager.yml || true; fi

echo
echo "=== 🗄️  Démarrage du service MySQL ==="
docker compose up -d mysql

echo
echo "=== ⏳ Attente de la disponibilité de MySQL ==="
until docker exec mysql mysqladmin ping -h 127.0.0.1 -P 3306 -p"$MYSQL_ROOT_PASSWORD" --silent 2>/dev/null; do
  echo "⏳ MySQL n'est pas encore prêt..."; sleep 2
done
echo "✅ MySQL est prêt."

sleep 2

echo
echo "=== 👤 Création (ou mise à jour) de l'utilisateur exporter ==="
cat <<SQL | docker exec -i mysql mysql -h 127.0.0.1 -P 3306 -uroot -p"$MYSQL_ROOT_PASSWORD"
CREATE USER IF NOT EXISTS '${MYSQL_EXPORTER_USER}'@'%' IDENTIFIED BY '${MYSQL_EXPORTER_PASSWORD}';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO '${MYSQL_EXPORTER_USER}'@'%';
FLUSH PRIVILEGES;
SQL
echo "✅ Utilisateur exporter configuré."

echo
echo "=== 📊 Démarrage de la stack métriques + logs + alerting ==="
docker compose up -d \
  prometheus \
  alertmanager \
  grafana \
  demo-app \
  mysqld-exporter \
  node-exporter-host \
  node-exporter-node2 \
  loki \
  promtail

echo
echo "=== 🔍 Vérification rapide : containers ==="
docker compose ps

echo
echo "=== 🔍 Vérification rapide : endpoints ==="

# Prometheus
curl -sf http://localhost:9090/-/healthy >/dev/null && echo "✅ Prometheus OK" || echo "❌ Prometheus KO"

# Alertmanager
curl -sf http://localhost:9093/-/ready >/dev/null && echo "✅ Alertmanager OK" || echo "❌ Alertmanager KO"

# Demo app metrics
curl -sf http://localhost:8080/metrics >/dev/null && echo "✅ Demo-app /metrics OK" || echo "❌ Demo-app KO"

# Grafana health
GRAFANA_WAIT=0; GRAFANA_TIMEOUT=30
until curl -sf http://localhost:3000/api/health | grep -q '"database":"ok"'; do
  echo "⏳ Grafana pas encore prêt..."; sleep 2; GRAFANA_WAIT=$((GRAFANA_WAIT+2))
  if [ "$GRAFANA_WAIT" -ge "$GRAFANA_TIMEOUT" ]; then
    echo "❌ Grafana KO (timeout ${GRAFANA_TIMEOUT}s). Logs: docker compose logs grafana"
    break
  fi
done
if [ "$GRAFANA_WAIT" -lt "$GRAFANA_TIMEOUT" ]; then echo "✅ Grafana OK"; fi

# Loki ready
LOKI_WAIT=0; LOKI_TIMEOUT=30
until curl -s -o /dev/null -w '%{http_code}' http://localhost:3100/ready | grep -q '^200$'; do
  echo "⏳ Loki pas encore prêt..."; sleep 2; LOKI_WAIT=$((LOKI_WAIT+2))
  if [ "$LOKI_WAIT" -ge "$LOKI_TIMEOUT" ]; then
    echo "❌ Loki KO (timeout ${LOKI_TIMEOUT}s). Logs: docker compose logs loki"
    break
  fi
done
if [ "$LOKI_WAIT" -lt "$LOKI_TIMEOUT" ]; then echo "✅ Loki OK"; fi

echo
echo "✅ Déploiement complet terminé !"
echo "Grafana → http://localhost:3000 (user/pass: ${GRAFANA_ADMIN_USER})"
echo "Prometheus → http://localhost:9090"
echo "Alertmanager → http://localhost:9093"
echo "Demo-app → http://localhost:8080 (metrics: /metrics)"
echo "Loki → http://localhost:3100/ready"