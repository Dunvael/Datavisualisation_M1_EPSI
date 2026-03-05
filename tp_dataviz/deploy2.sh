#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
# 🚀 Script de déploiement complet du TP Dataviz
# (ports + secrets via .env)
# ─────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ENV_FILE="$SCRIPT_DIR/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ Fichier .env introuvable à la racine du projet : $ENV_FILE"
  exit 1
fi

# Charger .env dans le shell (utile pour les checks et les commandes)
set -a
. "$ENV_FILE"
set +a

# ─────────────────────────────────────────────
# ✅ Vérifications variables indispensables
# ─────────────────────────────────────────────
: "${MYSQL_ROOT_PASSWORD:?Variable manquante dans .env}"
: "${MYSQL_EXPORTER_USER:?Variable manquante dans .env}"
: "${MYSQL_EXPORTER_PASSWORD:?Variable manquante dans .env}"
: "${MYSQL_HOST:?Variable manquante dans .env}"
: "${MYSQL_PORT:?Variable manquante dans .env}"
: "${MYSQL_EXPOSED_PORT:?Variable manquante dans .env}"
: "${MYSQL_EXPORTER_PORT:?Variable manquante dans .env}"

: "${GRAFANA_ADMIN_USER:?Variable manquante dans .env}"
: "${GRAFANA_ADMIN_PASSWORD:?Variable manquante dans .env}"
: "${GRAFANA_PORT:?Variable manquante dans .env}"

: "${PROMETHEUS_PORT:?Variable manquante dans .env}"
: "${ALERTMANAGER_PORT:?Variable manquante dans .env}"
: "${LOKI_PORT:?Variable manquante dans .env}"
: "${PROMTAIL_PORT:?Variable manquante dans .env}"
: "${DEMO_APP_PORT:?Variable manquante dans .env}"
: "${NODE_EXPORTER_HOST_PORT:?Variable manquante dans .env}"
: "${NODE_EXPORTER_NODE2_PORT:?Variable manquante dans .env}"

echo "=== 📦 Téléchargement des images ==="
docker compose pull

echo
echo "=== 🧼 Normalisation CRLF → LF sur les configs ==="
# Idempotent (sans effet si déjà en LF)
sed -i 's/\r$//' prometheus/prometheus.yml || true
sed -i 's/\r$//' loki/loki-config.yml || true
sed -i 's/\r$//' loki/promtail-config.yml || true
if [[ -d prometheus/rules ]]; then sed -i 's/\r$//' prometheus/rules/*.yml || true; fi
if [[ -f alertmanager/alertmanager.yml ]]; then sed -i 's/\r$//' alertmanager/alertmanager.yml || true; fi

echo
echo "=== 🗄️  Démarrage du service MySQL ==="
docker compose up -d mysql

echo
echo "=== ⏳ Attente de la disponibilité de MySQL (port hôte: ${MYSQL_EXPOSED_PORT}) ==="
until docker exec mysql mysqladmin ping -h 127.0.0.1 -P 3306 -p"$MYSQL_ROOT_PASSWORD" --silent 2>/dev/null; do
  # Note: depuis *le conteneur mysql*, c'est toujours 3306.
  # Le port exposé hôte (${MYSQL_EXPOSED_PORT}) sert pour accès depuis ta machine.
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
echo "=== 🔍 Vérification rapide : endpoints (ports hôte via .env) ==="

# Prometheus
if curl -sf "http://localhost:${PROMETHEUS_PORT}/-/healthy" >/dev/null; then
  echo "✅ Prometheus OK (http://localhost:${PROMETHEUS_PORT})"
else
  echo "❌ Prometheus KO (http://localhost:${PROMETHEUS_PORT})"
fi

# Alertmanager
if curl -sf "http://localhost:${ALERTMANAGER_PORT}/-/ready" >/dev/null; then
  echo "✅ Alertmanager OK (http://localhost:${ALERTMANAGER_PORT})"
else
  echo "❌ Alertmanager KO (http://localhost:${ALERTMANAGER_PORT})"
fi

# Demo app metrics
if curl -sf "http://localhost:${DEMO_APP_PORT}/metrics" >/dev/null; then
  echo "✅ Demo-app /metrics OK (http://localhost:${DEMO_APP_PORT})"
else
  echo "❌ Demo-app KO (http://localhost:${DEMO_APP_PORT})"
fi

# Grafana /api/health
GRAFANA_WAIT=0; GRAFANA_TIMEOUT=30
until curl -sf "http://localhost:${GRAFANA_PORT}/api/health" | grep -q '"database":"ok"'; do
  echo "⏳ Grafana pas encore prêt..."; sleep 2; GRAFANA_WAIT=$((GRAFANA_WAIT+2))
  if [ "$GRAFANA_WAIT" -ge "$GRAFANA_TIMEOUT" ]; then
    echo "❌ Grafana KO (timeout ${GRAFANA_TIMEOUT}s). Logs: docker compose logs grafana"
    break
  fi
done
if [ "$GRAFANA_WAIT" -lt "$GRAFANA_TIMEOUT" ]; then
  echo "✅ Grafana OK (http://localhost:${GRAFANA_PORT})"
fi

# Loki /ready
LOKI_WAIT=0; LOKI_TIMEOUT=30
until curl -s -o /dev/null -w '%{http_code}' "http://localhost:${LOKI_PORT}/ready" | grep -q '^200$'; do
  echo "⏳ Loki pas encore prêt..."; sleep 2; LOKI_WAIT=$((LOKI_WAIT+2))
  if [ "$LOKI_WAIT" -ge "$LOKI_TIMEOUT" ]; then
    echo "❌ Loki KO (timeout ${LOKI_TIMEOUT}s). Logs: docker compose logs loki"
    break
  fi
done
if [ "$LOKI_WAIT" -lt "$LOKI_TIMEOUT" ]; then
  echo "✅ Loki OK (http://localhost:${LOKI_PORT})"
fi

echo
echo "✅ Déploiement complet terminé !"
echo "Grafana      → http://localhost:${GRAFANA_PORT} (user: ${GRAFANA_ADMIN_USER})"
echo "Prometheus   → http://localhost:${PROMETHEUS_PORT}"
echo "Alertmanager → http://localhost:${ALERTMANAGER_PORT}"
echo "Demo-app     → http://localhost:${DEMO_APP_PORT} (metrics: /metrics)"
echo "Loki         → http://localhost:${LOKI_PORT}/ready"
echo
echo "ℹ️  Notes:"
echo "- Les ports hôte sont configurables via .env."
echo "- À l'intérieur du réseau Docker, les services utilisent leurs ports internes (ex: mysql:3306)."